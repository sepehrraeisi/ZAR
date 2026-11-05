#!/usr/bin/env python3
"""Run a synthetic transactional-restore commit and post-restart replay.

The canary is intentionally clone-only.  It accepts only an explicit loopback
HTTP URL, creates a random synthetic user/workspace, and never writes secrets or
snapshot payloads to its evidence file.  The separate replay-state file is
private (0600 on POSIX) and contains the credentials and exact request body
needed to prove idempotent replay after a real service restart.
"""

from __future__ import annotations

import argparse
import datetime as dt
import ipaddress
import json
import os
import re
import secrets
import stat
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


PROTOCOL_VERSION = 1
STATE_SCHEMA_VERSION = 1
EVIDENCE_SCHEMA_VERSION = 1
HASH_PATTERN = re.compile(r"^[a-f0-9]{64}$")
REQUEST_ID_PATTERN = re.compile(r"^[a-f0-9]{32}$")
COUNT_KEYS = (
    "people",
    "deals",
    "settlements",
    "coinTypes",
    "currencyTypes",
    "paymentAllocations",
    "cashEntries",
    "total",
)
EMPTY_COUNTS = {key: 0 for key in COUNT_KEYS}
EXPECTED_COUNTS = {
    "people": 1,
    "deals": 1,
    "settlements": 1,
    "coinTypes": 1,
    "currencyTypes": 1,
    "paymentAllocations": 1,
    "cashEntries": 1,
    "total": 7,
}
RECEIPT_KEYS = {
    "protocolVersion",
    "requestId",
    "workspaceId",
    "snapshotHash",
    "beforeHash",
    "afterHash",
    "counts",
    "committedAt",
    "replayed",
}
MAX_JSON_BYTES = 2 * 1024 * 1024
PRODUCTION_PORT = 8090
SERVER_ROOT = Path("/opt/zar/server")
PRODUCTION_DATA_DIR = SERVER_ROOT / "pb_data"
EXPECTED_POCKETBASE = SERVER_ROOT / "pocketbase"
CLONE_UNIT_PATTERN = re.compile(
    r"^zar-restore-clone-[A-Za-z0-9][A-Za-z0-9_.-]*\.service$"
)
CLONE_WORK_ROOT_PATTERN = re.compile(
    r"^restore-clone\.[A-Za-z0-9][A-Za-z0-9_.-]*$"
)
CLONE_CASE_PATTERN = re.compile(r"^case-[A-Za-z0-9][A-Za-z0-9_.-]*$")


class CanaryError(RuntimeError):
    """A fail-closed canary validation error."""


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(
        self,
        req: urllib.request.Request,
        fp: Any,
        code: int,
        msg: str,
        headers: Any,
        newurl: str,
    ) -> None:
        return None


_OPENER = urllib.request.build_opener(
    urllib.request.ProxyHandler({}),
    _NoRedirect(),
)


def _normalize_base_url(value: str, *, confirm_disposable_clone: bool) -> str:
    if not confirm_disposable_clone:
        raise CanaryError("explicit disposable-clone confirmation is required")
    try:
        parsed = urllib.parse.urlsplit(value)
        host = parsed.hostname
        port = parsed.port
    except ValueError as error:
        raise CanaryError("base URL is malformed") from error
    if (
        parsed.scheme != "http"
        or host is None
        or port is None
        or parsed.username is not None
        or parsed.password is not None
        or parsed.query
        or parsed.fragment
        or parsed.path not in ("", "/")
    ):
        raise CanaryError("base URL must be an explicit loopback HTTP origin")
    try:
        address = ipaddress.ip_address(host)
    except ValueError as error:
        raise CanaryError("base URL host must be a loopback IP literal") from error
    if not address.is_loopback:
        raise CanaryError("base URL host is not loopback")
    if port == PRODUCTION_PORT:
        raise CanaryError("production PocketBase port is forbidden")
    rendered_host = f"[{address.compressed}]" if address.version == 6 else address.compressed
    return f"http://{rendered_host}:{port}"


def _systemctl_property(unit: str, property_name: str) -> str:
    try:
        result = subprocess.run(
            ["systemctl", "show", unit, f"--property={property_name}", "--value"],
            check=False,
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError) as error:
        raise CanaryError("clone systemd identity could not be inspected") from error
    if result.returncode != 0:
        raise CanaryError("clone systemd identity could not be inspected")
    return result.stdout.strip()


def _exec_value(service_exec: str, name: str, label: str) -> str:
    values = re.findall(
        rf"(?:^|[ {{;]){re.escape(name)}=([^ ;}}]+)",
        service_exec,
    )
    if len(values) != 1:
        raise CanaryError(f"clone unit must define exactly one {label}")
    return values[0]


def _strict_existing_path(path: Path, label: str, *, directory: bool) -> os.stat_result:
    if not path.is_absolute():
        raise CanaryError(f"{label} must be absolute")
    try:
        metadata = path.lstat()
        resolved = path.resolve(strict=True)
    except OSError as error:
        raise CanaryError(f"{label} could not be inspected") from error
    if path.is_symlink() or resolved != path:
        raise CanaryError(f"{label} must not contain symlinks or traversal")
    expected_type = stat.S_ISDIR if directory else stat.S_ISREG
    if not expected_type(metadata.st_mode):
        kind = "directory" if directory else "regular file"
        raise CanaryError(f"{label} must be a {kind}")
    return metadata


def _verify_clone_exec_paths(
    service_exec: str,
    *,
    server_root: Path = SERVER_ROOT,
    production_data_dir: Path = PRODUCTION_DATA_DIR,
    expected_pocketbase: Path = EXPECTED_POCKETBASE,
) -> None:
    """Bind the active unit to one real disposable clone filesystem tree."""

    _strict_existing_path(server_root, "server root", directory=True)
    production_metadata = _strict_existing_path(
        production_data_dir,
        "production data directory",
        directory=True,
    )
    expected_pocketbase_metadata = _strict_existing_path(
        expected_pocketbase,
        "expected PocketBase executable",
        directory=False,
    )

    executable = Path(_exec_value(service_exec, "path", "executable path"))
    executable_metadata = _strict_existing_path(
        executable,
        "clone unit executable",
        directory=False,
    )
    if executable != expected_pocketbase or (
        executable_metadata.st_dev,
        executable_metadata.st_ino,
    ) != (
        expected_pocketbase_metadata.st_dev,
        expected_pocketbase_metadata.st_ino,
    ):
        raise CanaryError("clone unit executable is not the expected PocketBase binary")

    data_dir = Path(_exec_value(service_exec, "--dir", "data directory"))
    migrations_dir = Path(
        _exec_value(service_exec, "--migrationsDir", "migration directory")
    )
    hooks_dir = Path(_exec_value(service_exec, "--hooksDir", "hook directory"))
    data_metadata = _strict_existing_path(
        data_dir,
        "clone data directory",
        directory=True,
    )
    _strict_existing_path(
        migrations_dir,
        "clone migration directory",
        directory=True,
    )
    _strict_existing_path(hooks_dir, "clone hook directory", directory=True)

    case_root = data_dir.parent
    work_root = case_root.parent
    if (
        data_dir.name != "pb_data"
        or migrations_dir != case_root / "pb_migrations"
        or hooks_dir != case_root / "pb_hooks"
        or CLONE_CASE_PATTERN.fullmatch(case_root.name) is None
        or work_root.parent != server_root
        or CLONE_WORK_ROOT_PATTERN.fullmatch(work_root.name) is None
    ):
        raise CanaryError("clone unit paths are not one approved disposable tree")
    _strict_existing_path(case_root, "clone case root", directory=True)
    _strict_existing_path(work_root, "clone work root", directory=True)
    if (
        data_metadata.st_dev,
        data_metadata.st_ino,
    ) == (
        production_metadata.st_dev,
        production_metadata.st_ino,
    ):
        raise CanaryError("clone data directory aliases production")

    production_database_identities: set[tuple[int, int]] = set()
    for database_name in ("data.db", "auxiliary.db"):
        production_database_metadata = _strict_existing_path(
            production_data_dir / database_name,
            f"production {database_name}",
            directory=False,
        )
        production_database_identities.add(
            (production_database_metadata.st_dev, production_database_metadata.st_ino)
        )

    clone_database_identities: set[tuple[int, int]] = set()
    for database_name in ("data.db", "auxiliary.db"):
        clone_database = data_dir / database_name
        clone_database_metadata = _strict_existing_path(
            clone_database,
            f"clone {database_name}",
            directory=False,
        )
        clone_identity = (
            clone_database_metadata.st_dev,
            clone_database_metadata.st_ino,
        )
        if clone_identity in production_database_identities:
            raise CanaryError(f"clone {database_name} aliases production database")
        if clone_identity in clone_database_identities:
            raise CanaryError("clone databases must be distinct files")
        clone_database_identities.add(clone_identity)


def _verify_clone_identity(base_url: str, unit: str) -> None:
    if os.name != "posix":
        raise CanaryError("CLI clone identity verification requires POSIX systemd")
    if CLONE_UNIT_PATTERN.fullmatch(unit) is None or unit == "zar-server.service":
        raise CanaryError("clone unit name is not an approved disposable unit")
    if _systemctl_property(unit, "ActiveState") != "active":
        raise CanaryError("clone unit is not active")
    if _systemctl_property(unit, "User") != "zarapp":
        raise CanaryError("clone unit does not run as zarapp")
    fragment = _systemctl_property(unit, "FragmentPath")
    if fragment != f"/run/systemd/system/{unit}":
        raise CanaryError("clone unit is not loaded from the transient unit boundary")
    service_exec = _systemctl_property(unit, "ExecStart")
    expected_http = base_url.removeprefix("http://")
    if re.findall(r"--http=([^ ;]+)", service_exec) != [expected_http]:
        raise CanaryError("clone unit listener does not match the requested origin")
    if re.findall(r"--hooksWatch=([^ ;]+)", service_exec) != ["false"]:
        raise CanaryError("clone unit must disable hook watching")
    _verify_clone_exec_paths(service_exec)


def _absolute_path(path: Path, label: str) -> Path:
    if not path.is_absolute():
        raise CanaryError(f"{label} path must be absolute")
    parent = path.parent
    if not parent.exists() or not parent.is_dir() or parent.is_symlink():
        raise CanaryError(f"{label} parent must be an existing real directory")
    if os.name == "posix" and parent.resolve(strict=True) != parent:
        raise CanaryError(f"{label} parent must not traverse symlinks")
    if path.exists() or path.is_symlink():
        raise CanaryError(f"{label} path already exists")
    return path


def _private_state_path(path: Path) -> Path:
    if not path.is_absolute():
        raise CanaryError("state path must be absolute")
    if path.is_symlink() or not path.is_file():
        raise CanaryError("state path must be a regular non-symlink file")
    if os.name == "posix" and path.resolve(strict=True) != path:
        raise CanaryError("state path must not traverse symlinks")
    metadata = path.stat()
    if os.name == "posix":
        if stat.S_IMODE(metadata.st_mode) != 0o600:
            raise CanaryError("state path mode must be 0600")
        if metadata.st_uid != os.geteuid():
            raise CanaryError("state path must be owned by the current user")
    return path


def _write_private_json(path: Path, value: dict[str, Any]) -> None:
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor = os.open(path, flags, 0o600)
    try:
        if hasattr(os, "fchmod"):
            os.fchmod(descriptor, 0o600)
        payload = (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode(
            "utf-8"
        )
        with os.fdopen(descriptor, "wb", closefd=False) as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
    finally:
        os.close(descriptor)
    if os.name == "posix":
        os.chmod(path, 0o600)


def _read_private_json(path: Path, label: str) -> dict[str, Any]:
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(path, flags)
        try:
            metadata = os.fstat(descriptor)
            if not stat.S_ISREG(metadata.st_mode):
                raise CanaryError(f"{label} must be a regular file")
            if os.name == "posix" and (
                stat.S_IMODE(metadata.st_mode) != 0o600
                or metadata.st_uid != os.geteuid()
            ):
                raise CanaryError(f"{label} permissions changed during read")
            with os.fdopen(descriptor, "rb", closefd=False) as stream:
                raw = stream.read(MAX_JSON_BYTES + 1)
        finally:
            os.close(descriptor)
        if len(raw) > MAX_JSON_BYTES:
            raise CanaryError(f"{label} is too large")
        value = json.loads(raw.decode("utf-8"))
    except CanaryError:
        raise
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise CanaryError(f"{label} is not valid JSON") from error
    if not isinstance(value, dict):
        raise CanaryError(f"{label} must contain a JSON object")
    return value


def _request(
    base_url: str,
    method: str,
    path: str,
    *,
    body: dict[str, Any] | None = None,
    token: str | None = None,
) -> tuple[int, Any]:
    payload = None if body is None else json.dumps(body).encode("utf-8")
    headers = {"Accept": "application/json", "Content-Type": "application/json"}
    if token is not None:
        headers["Authorization"] = token
    request = urllib.request.Request(
        base_url + path,
        data=payload,
        headers=headers,
        method=method,
    )
    try:
        with _OPENER.open(request, timeout=10) as response:
            raw = response.read(MAX_JSON_BYTES + 1)
            if len(raw) > MAX_JSON_BYTES:
                raise CanaryError("server response is too large")
            try:
                decoded = json.loads(raw) if raw else None
            except json.JSONDecodeError as error:
                raise CanaryError("server returned malformed JSON") from error
            return int(response.status), decoded
    except urllib.error.HTTPError as error:
        # Never surface a server body: it could echo request data.
        error.read(MAX_JSON_BYTES + 1)
        return int(error.code), None
    except urllib.error.URLError as error:
        raise CanaryError("loopback request failed") from error


def _expect_status(label: str, status: int, expected: int) -> None:
    if status != expected:
        raise CanaryError(f"{label} returned HTTP {status}, expected {expected}")


def _object(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise CanaryError(f"{label} response is malformed")
    return value


def _timestamp_is_valid(value: Any) -> bool:
    if not isinstance(value, str) or not value:
        return False
    normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
    try:
        parsed = dt.datetime.fromisoformat(normalized)
    except ValueError:
        return False
    return parsed.tzinfo is not None


def _verify_counts(value: Any, expected: dict[str, int], label: str) -> dict[str, int]:
    if not isinstance(value, dict) or set(value) != set(COUNT_KEYS):
        raise CanaryError(f"{label} counts are malformed")
    if any(type(value[key]) is not int or value[key] < 0 for key in COUNT_KEYS):
        raise CanaryError(f"{label} counts are malformed")
    result = {key: int(value[key]) for key in COUNT_KEYS}
    if result != expected:
        raise CanaryError(f"{label} counts do not match the canary snapshot")
    return result


def _verify_restore_state(
    value: Any,
    *,
    workspace_id: str,
    expected_counts: dict[str, int],
) -> dict[str, Any]:
    state = _object(value, "restore state")
    state_hash = state.get("stateHash")
    if (
        state.get("protocolVersion") != PROTOCOL_VERSION
        or state.get("workspaceId") != workspace_id
        or not isinstance(state_hash, str)
        or HASH_PATTERN.fullmatch(state_hash) is None
    ):
        raise CanaryError("restore state response is malformed")
    counts = _verify_counts(state.get("counts"), expected_counts, "restore state")
    return {"stateHash": state_hash, "counts": counts}


def _verify_receipt(
    value: Any,
    *,
    request_id: str,
    workspace_id: str,
    before_hash: str,
    replayed: bool,
) -> dict[str, Any]:
    receipt = _object(value, "restore receipt")
    if set(receipt) != RECEIPT_KEYS:
        raise CanaryError("restore receipt fields are malformed")
    snapshot_hash = receipt.get("snapshotHash")
    after_hash = receipt.get("afterHash")
    if (
        receipt.get("protocolVersion") != PROTOCOL_VERSION
        or receipt.get("requestId") != request_id
        or receipt.get("workspaceId") != workspace_id
        or receipt.get("beforeHash") != before_hash
        or not isinstance(snapshot_hash, str)
        or HASH_PATTERN.fullmatch(snapshot_hash) is None
        or after_hash != snapshot_hash
        or receipt.get("replayed") is not replayed
        or not _timestamp_is_valid(receipt.get("committedAt"))
    ):
        raise CanaryError("restore receipt values are malformed")
    counts = _verify_counts(receipt.get("counts"), EXPECTED_COUNTS, "restore receipt")
    return {
        "protocolVersion": PROTOCOL_VERSION,
        "requestId": request_id,
        "workspaceId": workspace_id,
        "snapshotHash": snapshot_hash,
        "beforeHash": before_hash,
        "afterHash": after_hash,
        "counts": counts,
        "committedAt": receipt["committedAt"],
        "replayed": replayed,
    }


def _snapshot(suffix: str, workspace_id: str) -> dict[str, Any]:
    timestamp = "2026-11-03T00:00:00.000Z"
    person_id = f"canary-person-{suffix}"
    deal_id = f"canary-deal-{suffix}"
    settlement_id = f"canary-settlement-{suffix}"
    coin_type_id = f"canary-coin-{suffix}"
    currency_type_id = f"canary-currency-{suffix}"
    allocation_id = f"alloc-{settlement_id}-deal-{deal_id}"
    cash_id = f"canary-cash-{suffix}"
    return {
        "people": [
            {
                "id": person_id,
                "data": {
                    "id": person_id,
                    "displayName": "Clone canary person",
                    "phone": None,
                    "note": None,
                    "archived": False,
                    "createdAt": timestamp,
                    "updatedAt": timestamp,
                    "createdBy": "clone-canary",
                },
            }
        ],
        "deals": [
            {
                "id": deal_id,
                "data": {
                    "id": deal_id,
                    "type": "sell",
                    "personId": person_id,
                    "amount": {
                        "assetType": "currency",
                        "currency": {
                            "code": "USD",
                            "minorUnits": 100,
                            "minorUnitScale": 2,
                        },
                    },
                    "pricing": {
                        "kind": "currency",
                        "tomanPerUnit": "1000",
                        "totalToman": {"wholeTomans": 1000},
                    },
                    "dealAt": timestamp,
                    "status": "active",
                    "note": None,
                    "createdBy": "clone-canary",
                    "createdAt": timestamp,
                    "updatedAt": timestamp,
                },
            }
        ],
        "settlements": [
            {
                "id": settlement_id,
                "data": {
                    "id": settlement_id,
                    "dealId": None,
                    "personId": person_id,
                    "direction": "receive",
                    "amount": {
                        "assetType": "currency",
                        "currency": {
                            "code": "TOMAN",
                            "minorUnits": 500,
                            "minorUnitScale": 0,
                        },
                    },
                    "scheduledAt": timestamp,
                    "hasTime": False,
                    "status": "completed",
                    "reminderPlan": {"rules": [], "snoozedUntil": None},
                    "coinValuation": None,
                    "completedAt": "2026-11-03T01:00:00.000Z",
                    "completedBy": "clone-canary",
                    "note": None,
                    "createdBy": "clone-canary",
                    "createdAt": timestamp,
                    "updatedAt": "2026-11-03T01:00:00.000Z",
                },
            }
        ],
        "coinTypes": [
            {
                "id": coin_type_id,
                "data": {
                    "id": coin_type_id,
                    "name": "Clone canary coin",
                    "category": "official",
                    "defaultWeightGrams": "8.133",
                    "defaultFineness": "900",
                    "defaultPricingMethod": "perPiece",
                    "archived": False,
                    "createdAt": timestamp,
                    "updatedAt": timestamp,
                },
            }
        ],
        "currencyTypes": [
            {
                "id": currency_type_id,
                "data": {
                    "id": currency_type_id,
                    "name": "Clone canary currency",
                    "code": "USD",
                    "archived": False,
                    "createdAt": timestamp,
                    "updatedAt": timestamp,
                },
            }
        ],
        "paymentAllocations": [
            {
                "id": allocation_id,
                "data": {
                    "settlementId": settlement_id,
                    "targetType": "deal",
                    "targetId": deal_id,
                    "amountToman": 500,
                },
            }
        ],
        "cashEntries": [
            {
                "id": cash_id,
                "data": {
                    "id": cash_id,
                    "businessId": workspace_id,
                    "kind": "contribution",
                    "direction": "receive",
                    "amount": {
                        "assetType": "currency",
                        "currency": {
                            "code": "TOMAN",
                            "minorUnits": 1000,
                            "minorUnitScale": 0,
                        },
                    },
                    "occurredAt": timestamp,
                    "note": "Clone canary cash entry",
                    "dealId": None,
                    "reversesId": None,
                    "countedQuantity": None,
                    "expectedQuantity": None,
                },
            }
        ],
    }


def _authenticate(base_url: str, identity: str, password: str) -> tuple[str, str]:
    status, response = _request(
        base_url,
        "POST",
        "/api/collections/users/auth-with-password",
        body={"identity": identity, "password": password},
    )
    _expect_status("clone user authentication", status, 200)
    authentication = _object(response, "authentication")
    token = authentication.get("token")
    record = authentication.get("record")
    if not isinstance(token, str) or not token or not isinstance(record, dict):
        raise CanaryError("authentication response is malformed")
    user_id = record.get("id")
    if not isinstance(user_id, str) or not user_id:
        raise CanaryError("authentication record is malformed")
    return token, user_id


def _verify_receipt_privacy(base_url: str, token: str) -> None:
    status, _ = _request(
        base_url,
        "GET",
        "/api/collections/zar_restore_receipts/records",
        token=token,
    )
    _expect_status("private receipt Record API", status, 403)


def _evidence(action: str, receipt: dict[str, Any], state: dict[str, Any]) -> dict[str, Any]:
    return {
        "schemaVersion": EVIDENCE_SCHEMA_VERSION,
        "action": action,
        "status": "pass",
        "generatedAtUtc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "receipt": receipt,
        "postCommitState": state,
        "privacy": {"receiptRecordApiHttpStatus": 403},
    }


def run_commit(
    base_url: str,
    state_path: Path,
    output_path: Path,
    *,
    confirm_disposable_clone: bool,
) -> dict[str, Any]:
    normalized_url = _normalize_base_url(
        base_url,
        confirm_disposable_clone=confirm_disposable_clone,
    )
    state_path = _absolute_path(state_path, "state")
    output_path = _absolute_path(output_path, "output")
    if state_path.resolve() == output_path.resolve():
        raise CanaryError("state and output paths must be different")

    suffix = secrets.token_hex(4)
    identity = f"restore-clone-{suffix}@example.test"
    password = f"ZarClone-{secrets.token_hex(12)}-Aa1!"
    status, signup_response = _request(
        normalized_url,
        "POST",
        "/api/collections/users/records",
        body={"email": identity, "password": password, "passwordConfirm": password},
    )
    _expect_status("clone user creation", status, 200)
    signup = _object(signup_response, "user creation")
    signup_user_id = signup.get("id")
    if not isinstance(signup_user_id, str) or not signup_user_id:
        raise CanaryError("user creation response is malformed")

    token, user_id = _authenticate(normalized_url, identity, password)
    if user_id != signup_user_id:
        raise CanaryError("authenticated user does not match created user")

    status, workspace_response = _request(
        normalized_url,
        "POST",
        "/api/collections/zar_workspaces/records",
        body={"displayName": "ZAR restore clone canary", "members": [user_id]},
        token=token,
    )
    _expect_status("clone workspace creation", status, 200)
    workspace = _object(workspace_response, "workspace creation")
    workspace_id = workspace.get("id")
    if not isinstance(workspace_id, str) or not workspace_id:
        raise CanaryError("workspace creation response is malformed")

    status, _ = _request(
        normalized_url,
        "PATCH",
        f"/api/collections/users/records/{urllib.parse.quote(user_id, safe='')}",
        body={"workspace": workspace_id},
        token=token,
    )
    _expect_status("clone workspace selection", status, 200)

    status, state_response = _request(
        normalized_url,
        "GET",
        "/api/zar/restore/state",
        token=token,
    )
    _expect_status("initial restore state", status, 200)
    initial_state = _verify_restore_state(
        state_response,
        workspace_id=workspace_id,
        expected_counts=EMPTY_COUNTS,
    )

    request_id = secrets.token_hex(16)
    request_body = {
        "protocolVersion": PROTOCOL_VERSION,
        "requestId": request_id,
        "businessId": workspace_id,
        "confirmationPassword": password,
        "expectedStateHash": initial_state["stateHash"],
        "snapshot": _snapshot(suffix, workspace_id),
    }
    status, receipt_response = _request(
        normalized_url,
        "POST",
        "/api/zar/restore/commit",
        body=request_body,
        token=token,
    )
    _expect_status("transactional restore commit", status, 200)
    receipt = _verify_receipt(
        receipt_response,
        request_id=request_id,
        workspace_id=workspace_id,
        before_hash=str(initial_state["stateHash"]),
        replayed=False,
    )

    status, final_state_response = _request(
        normalized_url,
        "GET",
        "/api/zar/restore/state",
        token=token,
    )
    _expect_status("post-commit restore state", status, 200)
    final_state = _verify_restore_state(
        final_state_response,
        workspace_id=workspace_id,
        expected_counts=EXPECTED_COUNTS,
    )
    if final_state["stateHash"] != receipt["afterHash"]:
        raise CanaryError("post-commit state hash does not match the receipt")
    _verify_receipt_privacy(normalized_url, token)

    private_state = {
        "schemaVersion": STATE_SCHEMA_VERSION,
        "baseUrl": normalized_url,
        "identity": identity,
        "password": password,
        "token": token,
        "userId": user_id,
        "workspaceId": workspace_id,
        "requestBody": request_body,
        "receipt": receipt,
    }
    evidence = _evidence("commit", receipt, final_state)
    state_written = False
    try:
        _write_private_json(state_path, private_state)
        state_written = True
        _write_private_json(output_path, evidence)
    except Exception:
        if state_written:
            state_path.unlink(missing_ok=True)
        raise
    return evidence


def _validated_replay_state(value: dict[str, Any], base_url: str) -> dict[str, Any]:
    required = {
        "schemaVersion",
        "baseUrl",
        "identity",
        "password",
        "token",
        "userId",
        "workspaceId",
        "requestBody",
        "receipt",
    }
    if set(value) != required or value.get("schemaVersion") != STATE_SCHEMA_VERSION:
        raise CanaryError("private replay state fields are malformed")
    if value.get("baseUrl") != base_url:
        raise CanaryError("private replay state belongs to another loopback origin")
    for key in ("identity", "password", "token", "userId", "workspaceId"):
        if not isinstance(value.get(key), str) or not value[key]:
            raise CanaryError("private replay state values are malformed")
    body = value.get("requestBody")
    stored_receipt = value.get("receipt")
    if not isinstance(body, dict) or not isinstance(stored_receipt, dict):
        raise CanaryError("private replay state values are malformed")
    if (
        body.get("requestId") != stored_receipt.get("requestId")
        or body.get("businessId") != value["workspaceId"]
        or body.get("confirmationPassword") != value["password"]
        or body.get("expectedStateHash") != stored_receipt.get("beforeHash")
        or REQUEST_ID_PATTERN.fullmatch(str(body.get("requestId", ""))) is None
    ):
        raise CanaryError("private replay request does not match its receipt")
    return value


def run_replay(
    base_url: str,
    state_path: Path,
    output_path: Path,
    *,
    confirm_disposable_clone: bool,
) -> dict[str, Any]:
    normalized_url = _normalize_base_url(
        base_url,
        confirm_disposable_clone=confirm_disposable_clone,
    )
    state_path = _private_state_path(state_path)
    output_path = _absolute_path(output_path, "output")
    state = _validated_replay_state(
        _read_private_json(state_path, "private replay state"),
        normalized_url,
    )

    token, user_id = _authenticate(
        normalized_url,
        str(state["identity"]),
        str(state["password"]),
    )
    if user_id != state["userId"]:
        raise CanaryError("re-authenticated user does not match private replay state")

    request_body = state["requestBody"]
    stored_receipt = state["receipt"]
    status, receipt_response = _request(
        normalized_url,
        "POST",
        "/api/zar/restore/commit",
        body=request_body,
        token=token,
    )
    _expect_status("transactional restore replay", status, 200)
    receipt = _verify_receipt(
        receipt_response,
        request_id=str(request_body["requestId"]),
        workspace_id=str(state["workspaceId"]),
        before_hash=str(request_body["expectedStateHash"]),
        replayed=True,
    )
    expected_receipt = dict(stored_receipt)
    expected_receipt["replayed"] = True
    if receipt != expected_receipt:
        raise CanaryError("replayed receipt metadata differs from the original receipt")

    status, final_state_response = _request(
        normalized_url,
        "GET",
        "/api/zar/restore/state",
        token=token,
    )
    _expect_status("post-replay restore state", status, 200)
    final_state = _verify_restore_state(
        final_state_response,
        workspace_id=str(state["workspaceId"]),
        expected_counts=EXPECTED_COUNTS,
    )
    if final_state["stateHash"] != receipt["afterHash"]:
        raise CanaryError("post-replay state hash does not match the receipt")
    _verify_receipt_privacy(normalized_url, token)

    evidence = _evidence("replay", receipt, final_state)
    _write_private_json(output_path, evidence)
    return evidence


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command in ("commit", "replay"):
        subparser = subparsers.add_parser(command)
        subparser.add_argument("--base-url", required=True)
        subparser.add_argument("--clone-unit", required=True)
        subparser.add_argument(
            "--confirm-disposable-clone",
            required=True,
            action="store_true",
        )
        subparser.add_argument("--state", required=True, type=Path)
        subparser.add_argument("--output", required=True, type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    arguments = _parser().parse_args(argv)
    try:
        normalized_url = _normalize_base_url(
            arguments.base_url,
            confirm_disposable_clone=arguments.confirm_disposable_clone,
        )
        _verify_clone_identity(normalized_url, arguments.clone_unit)
        if arguments.command == "commit":
            run_commit(
                normalized_url,
                arguments.state,
                arguments.output,
                confirm_disposable_clone=True,
            )
        else:
            run_replay(
                normalized_url,
                arguments.state,
                arguments.output,
                confirm_disposable_clone=True,
            )
    except CanaryError as error:
        print(f"TRANSACTIONAL_RESTORE_CANARY_FAILED: {error}", file=sys.stderr)
        return 1
    print(f"TRANSACTIONAL_RESTORE_CANARY_PASS action={arguments.command}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
