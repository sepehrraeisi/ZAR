"""Disposable integration tests for the server-side ZAR restore boundary.

The test uses the repository migrations and hooks with PocketBase 0.40.4. It
never contacts production and proves authorization, cash restoration, compare-
and-swap conflict handling, idempotent replay, and transaction rollback.
"""

from __future__ import annotations

import argparse
import json
import secrets
import shutil
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind(("127.0.0.1", 0))
        return int(listener.getsockname()[1])


def _request(
    base_url: str,
    method: str,
    path: str,
    *,
    body: dict[str, Any] | None = None,
    token: str | None = None,
) -> tuple[int, Any]:
    payload = None if body is None else json.dumps(body).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = token
    request = urllib.request.Request(
        f"{base_url}{path}",
        data=payload,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            decoded = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            decoded = raw.decode("utf-8", errors="replace")
        return error.code, decoded


def _expect(label: str, actual: int, expected: int) -> None:
    if actual != expected:
        raise AssertionError(f"{label}: expected HTTP {expected}, got {actual}")
    print(f"PASS {label}: HTTP {actual}")


def _wait_for_health(base_url: str, process: subprocess.Popen[Any]) -> None:
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(
                f"PocketBase exited before health check (exit {process.returncode})"
            )
        try:
            status, _ = _request(base_url, "GET", "/api/health")
            if status == 200:
                return
        except urllib.error.URLError:
            pass
        time.sleep(0.2)
    raise TimeoutError("PocketBase did not become healthy within 30 seconds")


def _migrate(pocketbase: Path, data_dir: Path, migrations_dir: Path) -> None:
    result = subprocess.run(
        [
            str(pocketbase),
            "migrate",
            "up",
            f"--dir={data_dir}",
            f"--migrationsDir={migrations_dir}",
        ],
        check=False,
        capture_output=True,
        text=True,
        timeout=60,
    )
    if result.returncode != 0:
        raise RuntimeError(f"PocketBase migration failed:\n{result.stdout}{result.stderr}")


def _signup(base_url: str, label: str) -> tuple[str, str, str]:
    suffix = secrets.token_hex(8)
    email = f"restore-{label}-{suffix}@example.test"
    password = f"Restore-{suffix}-Aa1!"
    status, user = _request(
        base_url,
        "POST",
        "/api/collections/users/records",
        body={"email": email, "password": password, "passwordConfirm": password},
    )
    _expect(f"{label} signup", status, 200)
    status, authentication = _request(
        base_url,
        "POST",
        "/api/collections/users/auth-with-password",
        body={"identity": email, "password": password},
    )
    _expect(f"{label} authentication", status, 200)
    return str(user["id"]), str(authentication["token"]), password


def _workspace(
    base_url: str, label: str, user_id: str, token: str
) -> str:
    status, workspace = _request(
        base_url,
        "POST",
        "/api/collections/zar_workspaces/records",
        body={"displayName": label, "members": [user_id]},
        token=token,
    )
    _expect(f"{label} workspace create", status, 200)
    workspace_id = str(workspace["id"])
    status, _ = _request(
        base_url,
        "PATCH",
        f"/api/collections/users/records/{user_id}",
        body={"workspace": workspace_id},
        token=token,
    )
    _expect(f"{label} workspace pin", status, 200)
    return workspace_id


def _person_row(person_id: str, name: str) -> dict[str, Any]:
    return {
        "id": person_id,
        "data": {
            "id": person_id,
            "displayName": name,
            "phone": None,
            "note": None,
            "archived": False,
            "createdAt": "2026-11-01T00:00:00.000Z",
            "updatedAt": "2026-11-01T00:00:00.000Z",
            "createdBy": "restore-test",
        },
    }


def _cash_row(cash_id: str, workspace_id: str) -> dict[str, Any]:
    return {
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
            "occurredAt": "2026-11-01T00:00:00.000Z",
            "note": "Transactional restore test",
            "dealId": None,
            "reversesId": None,
            "countedQuantity": None,
            "expectedQuantity": None,
        },
    }


def _coin_type_row() -> dict[str, Any]:
    return {
        "id": "coin-full",
        "data": {
            "id": "coin-full",
            "name": "Full coin",
            "category": "official",
            "defaultWeightGrams": "8.133",
            "defaultFineness": "900",
            "defaultPricingMethod": "perPiece",
            "archived": False,
            "createdAt": "2026-11-01T00:00:00.000Z",
            "updatedAt": "2026-11-01T00:00:00.000Z",
        },
    }


def _currency_type_row() -> dict[str, Any]:
    return {
        "id": "currency-usd",
        "data": {
            "id": "currency-usd",
            "name": "US Dollar",
            "code": "USD",
            "archived": False,
            "createdAt": "2026-11-01T00:00:00.000Z",
            "updatedAt": "2026-11-01T00:00:00.000Z",
        },
    }


def _deal_row() -> dict[str, Any]:
    return {
        "id": "deal-full",
        "data": {
            "id": "deal-full",
            "type": "sell",
            "personId": "person-new",
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
            "dealAt": "2026-11-01T00:00:00.000Z",
            "status": "active",
            "note": None,
            "createdBy": "restore-test",
            "createdAt": "2026-11-01T00:00:00.000Z",
            "updatedAt": "2026-11-01T00:00:00.000Z",
        },
    }


def _settlement_row() -> dict[str, Any]:
    return {
        "id": "settlement-source",
        "data": {
            "id": "settlement-source",
            "dealId": None,
            "personId": "person-new",
            "direction": "receive",
            "amount": {
                "assetType": "currency",
                "currency": {
                    "code": "TOMAN",
                    "minorUnits": 500,
                    "minorUnitScale": 0,
                },
            },
            "scheduledAt": "2026-11-01T00:00:00.000Z",
            "hasTime": False,
            "status": "completed",
            "reminderPlan": {"rules": [], "snoozedUntil": None},
            "coinValuation": None,
            "completedAt": "2026-11-01T01:00:00.000Z",
            "completedBy": "restore-test",
            "note": None,
            "createdBy": "restore-test",
            "createdAt": "2026-11-01T00:00:00.000Z",
            "updatedAt": "2026-11-01T01:00:00.000Z",
        },
    }


def _coin_settlement_row() -> dict[str, Any]:
    return {
        "id": "settlement-coin",
        "data": {
            "id": "settlement-coin",
            "dealId": None,
            "personId": "person-new",
            "direction": "deliver",
            "amount": {
                "assetType": "coin",
                "coinLines": [
                    {
                        "id": "coin-line-full",
                        "coinTypeId": "coin-full",
                        "coinTypeNameSnapshot": "Full coin",
                        "quantity": 2,
                        "weightPerPieceGrams": "8.133",
                        "fineness": "900",
                    }
                ],
            },
            "scheduledAt": "2026-11-02T00:00:00.000Z",
            "hasTime": True,
            "status": "open",
            "reminderPlan": {
                "rules": [
                    {
                        "id": "offset-60",
                        "type": "offset",
                        "minutesBefore": 60,
                        "customAt": None,
                        "enabled": True,
                    },
                    {
                        "id": "custom-one",
                        "type": "custom",
                        "minutesBefore": None,
                        "customAt": "2026-11-01T12:00:00.000Z",
                        "enabled": False,
                    },
                ],
                "snoozedUntil": "2026-11-01T06:00:00.000Z",
            },
            "coinValuation": {
                "lines": [
                    {
                        "lineId": "coin-line-full",
                        "method": "perPiece",
                        "unitPriceToman": {"wholeTomans": 100},
                        "priceReferenceFineness": None,
                        "rowTotalToman": {"wholeTomans": 200},
                    }
                ],
                "totalToman": {"wholeTomans": 200},
            },
            "completedAt": None,
            "completedBy": None,
            "note": "Coin settlement",
            "createdBy": "restore-test",
            "createdAt": "2026-11-01T00:00:00.000Z",
            "updatedAt": "2026-11-01T00:00:00.000Z",
        },
    }


def _allocation_row() -> dict[str, Any]:
    allocation_id = "alloc-settlement-source-deal-deal-full"
    return {
        "id": allocation_id,
        "data": {
            "settlementId": "settlement-source",
            "targetType": "deal",
            "targetId": "deal-full",
            "amountToman": 500,
        },
    }


def _snapshot(
    *,
    people: list[dict[str, Any]] | None = None,
    deals: list[dict[str, Any]] | None = None,
    settlements: list[dict[str, Any]] | None = None,
    coin_types: list[dict[str, Any]] | None = None,
    currency_types: list[dict[str, Any]] | None = None,
    payment_allocations: list[dict[str, Any]] | None = None,
    cash_entries: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    return {
        "people": people or [],
        "deals": deals or [],
        "settlements": settlements or [],
        "coinTypes": coin_types or [],
        "currencyTypes": currency_types or [],
        "paymentAllocations": payment_allocations or [],
        "cashEntries": cash_entries or [],
    }


def _create_person(
    base_url: str,
    token: str,
    workspace_id: str,
    person_id: str,
    name: str,
) -> None:
    row = _person_row(person_id, name)
    status, _ = _request(
        base_url,
        "POST",
        "/api/collections/zar_people/records",
        body={"id": row["id"], "workspace": workspace_id, "data": row["data"]},
        token=token,
    )
    _expect(f"create person {person_id}", status, 200)


def _restore_body(
    request_id: str,
    workspace_id: str,
    expected_hash: str,
    snapshot: dict[str, Any],
    confirmation_password: str,
) -> dict[str, Any]:
    return {
        "protocolVersion": 1,
        "requestId": request_id,
        "businessId": workspace_id,
        "confirmationPassword": confirmation_password,
        "expectedStateHash": expected_hash,
        "snapshot": snapshot,
    }


def run(pocketbase: Path) -> None:
    if not pocketbase.is_file():
        raise FileNotFoundError(f"PocketBase binary not found: {pocketbase}")
    repository_root = Path(__file__).resolve().parents[2]
    port = _free_port()
    base_url = f"http://127.0.0.1:{port}"

    with tempfile.TemporaryDirectory(
        prefix="zar-transactional-restore-", ignore_cleanup_errors=True
    ) as temp:
        root = Path(temp)
        data_dir = root / "pb_data"
        migrations_dir = root / "pb_migrations"
        hooks_dir = root / "pb_hooks"
        log_path = root / "pocketbase.log"
        shutil.copytree(repository_root / "server" / "pb_migrations", migrations_dir)
        shutil.copytree(repository_root / "server" / "pb_hooks", hooks_dir)
        _migrate(pocketbase, data_dir, migrations_dir)

        with log_path.open("w", encoding="utf-8") as log:
            process = subprocess.Popen(
                [
                    str(pocketbase),
                    "serve",
                    f"--http=127.0.0.1:{port}",
                    f"--dir={data_dir}",
                    f"--migrationsDir={migrations_dir}",
                    f"--hooksDir={hooks_dir}",
                    "--hooksWatch=false",
                ],
                cwd=repository_root,
                stdout=log,
                stderr=subprocess.STDOUT,
                text=True,
            )
            try:
                _wait_for_health(base_url, process)

                status, _ = _request(base_url, "GET", "/api/zar/restore/state")
                _expect("anonymous restore state denied", status, 401)

                user1, token1, password1 = _signup(base_url, "owner-one")
                workspace1 = _workspace(base_url, "owner-one", user1, token1)
                _create_person(base_url, token1, workspace1, "person-old", "Old")

                status, state1 = _request(
                    base_url, "GET", "/api/zar/restore/state", token=token1
                )
                _expect("authorized restore state", status, 200)
                if state1["workspaceId"] != workspace1 or len(state1["stateHash"]) != 64:
                    raise AssertionError("restore state response is malformed")

                request1 = "1" * 32
                restored = _snapshot(
                    people=[
                        _person_row("person-new", "New"),
                        _person_row("AA", "Upper"),
                        _person_row("aB", "Mixed"),
                        _person_row("_a", "Underscore"),
                        _person_row("-a", "Dash"),
                    ],
                    deals=[_deal_row()],
                    settlements=[_settlement_row(), _coin_settlement_row()],
                    coin_types=[_coin_type_row()],
                    currency_types=[_currency_type_row()],
                    payment_allocations=[_allocation_row()],
                    cash_entries=[_cash_row("cash-restored", workspace1)],
                )
                wrong_password_body = _restore_body(
                    "0" * 32,
                    workspace1,
                    str(state1["stateHash"]),
                    restored,
                    "wrong-password",
                )
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/restore/commit",
                    body=wrong_password_body,
                    token=token1,
                )
                _expect("restore requires password step-up", status, 428)
                body1 = _restore_body(
                    request1,
                    workspace1,
                    str(state1["stateHash"]),
                    restored,
                    password1,
                )
                status, receipt1 = _request(
                    base_url,
                    "POST",
                    "/api/zar/restore/commit",
                    body=body1,
                    token=token1,
                )
                _expect("cash snapshot transactional restore", status, 200)
                if receipt1["replayed"] or receipt1["requestId"] != request1:
                    raise AssertionError("first restore receipt is malformed")
                if receipt1["afterHash"] != receipt1["snapshotHash"]:
                    raise AssertionError("restore post-write hash was not verified")
                expected_counts = {
                    "people": 5,
                    "deals": 1,
                    "settlements": 2,
                    "coinTypes": 1,
                    "currencyTypes": 1,
                    "paymentAllocations": 1,
                    "cashEntries": 1,
                    "total": 12,
                }
                if receipt1["counts"] != expected_counts:
                    raise AssertionError("restore receipt collection counts are malformed")

                status, _ = _request(
                    base_url,
                    "GET",
                    "/api/collections/zar_people/records/person-old",
                    token=token1,
                )
                _expect("replaced person removed", status, 404)
                status, _ = _request(
                    base_url,
                    "GET",
                    "/api/collections/zar_people/records/person-new",
                    token=token1,
                )
                _expect("restored person present", status, 200)
                cash_path = "/api/collections/zar_cash_entries/records/cash-restored"
                status, restored_cash = _request(
                    base_url, "GET", cash_path, token=token1
                )
                _expect("restored cash present", status, 200)
                if (
                    restored_cash["data"]["amount"]["currency"]["minorUnits"]
                    != 1000
                ):
                    raise AssertionError("restored cash JSON changed numeric values")
                status, _ = _request(base_url, "DELETE", cash_path, token=token1)
                _expect("restored cash remains append-only", status, 403)

                status, _ = _request(
                    base_url,
                    "GET",
                    "/api/collections/zar_restore_receipts/records",
                    token=token1,
                )
                _expect("receipt collection remains private", status, 403)

                status, replay = _request(
                    base_url,
                    "POST",
                    "/api/zar/restore/commit",
                    body=body1,
                    token=token1,
                )
                _expect("same request id replays safely", status, 200)
                if not replay["replayed"] or replay["snapshotHash"] != receipt1["snapshotHash"]:
                    raise AssertionError("idempotent replay did not return the original receipt")

                changed_reuse = json.loads(json.dumps(body1))
                changed_reuse["snapshot"]["people"].append(
                    _person_row("person-reused", "Must not be written")
                )
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/restore/commit",
                    body=changed_reuse,
                    token=token1,
                )
                _expect("request id cannot be reused for another snapshot", status, 409)
                status, _ = _request(
                    base_url,
                    "GET",
                    "/api/collections/zar_people/records/person-reused",
                    token=token1,
                )
                _expect("conflicting request id performs no mutation", status, 404)

                status, stale_state = _request(
                    base_url, "GET", "/api/zar/restore/state", token=token1
                )
                _expect("state captured before concurrent write", status, 200)
                _create_person(
                    base_url, token1, workspace1, "person-concurrent", "Concurrent"
                )
                stale_body = _restore_body(
                    "2" * 32,
                    workspace1,
                    str(stale_state["stateHash"]),
                    restored,
                    password1,
                )
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/restore/commit",
                    body=stale_body,
                    token=token1,
                )
                _expect("stale restore rejected", status, 409)
                status, _ = _request(
                    base_url,
                    "GET",
                    "/api/collections/zar_people/records/person-concurrent",
                    token=token1,
                )
                _expect("concurrent write survives rejected restore", status, 200)

                _create_person(
                    base_url, token1, workspace1, "zz-collision", "Other owner"
                )
                user2, token2, password2 = _signup(base_url, "owner-two")
                workspace2 = _workspace(base_url, "owner-two", user2, token2)
                _create_person(base_url, token2, workspace2, "person-two-old", "Old two")
                status, state2 = _request(
                    base_url, "GET", "/api/zar/restore/state", token=token2
                )
                _expect("second workspace restore state", status, 200)
                collision_snapshot = _snapshot(
                    people=[
                        _person_row("aa-good", "Would be inserted first"),
                        _person_row("zz-collision", "Conflicting id"),
                    ]
                )
                collision_body = _restore_body(
                    "3" * 32,
                    workspace2,
                    str(state2["stateHash"]),
                    collision_snapshot,
                    password2,
                )
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/restore/commit",
                    body=collision_body,
                    token=token2,
                )
                if status < 400 or status == 429:
                    raise AssertionError(
                        f"collision restore should fail transactionally, got HTTP {status}"
                    )
                print(f"PASS collision restore failed transactionally: HTTP {status}")
                status, _ = _request(
                    base_url,
                    "GET",
                    "/api/collections/zar_people/records/person-two-old",
                    token=token2,
                )
                _expect("failed restore rolls back original deletion", status, 200)
                status, _ = _request(
                    base_url,
                    "GET",
                    "/api/collections/zar_people/records/aa-good",
                    token=token2,
                )
                _expect("failed restore rolls back partial insert", status, 404)

                status, _ = _request(
                    base_url,
                    "PATCH",
                    f"/api/collections/zar_workspaces/records/{workspace2}",
                    body={"members": [user2, user1]},
                    token=token2,
                )
                _expect("existing workspace membership is immutable", status, 404)

                case_duplicate_body = _restore_body(
                    "4" * 32,
                    workspace2,
                    str(state2["stateHash"]),
                    _snapshot(
                        people=[
                            _person_row("CaseDuplicate", "Upper"),
                            _person_row("caseduplicate", "Lower"),
                        ]
                    ),
                    password2,
                )
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/restore/commit",
                    body=case_duplicate_body,
                    token=token2,
                )
                _expect("case-insensitive duplicate ids rejected before mutation", status, 400)

                missing_reference = _snapshot()
                missing_reference["deals"] = [
                    {"id": "deal-bad", "data": {"id": "deal-bad", "personId": "constructor"}}
                ]
                invalid_reference_body = _restore_body(
                    "5" * 32,
                    workspace2,
                    str(state2["stateHash"]),
                    missing_reference,
                    password2,
                )
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/restore/commit",
                    body=invalid_reference_body,
                    token=token2,
                )
                _expect("prototype-like missing reference rejected", status, 400)

                first_opening = _cash_row("opening-one", workspace2)
                second_opening = _cash_row("opening-two", workspace2)
                first_opening["data"]["kind"] = "opening"
                second_opening["data"]["kind"] = "opening"
                invalid_accounting_body = _restore_body(
                    "6" * 32,
                    workspace2,
                    str(state2["stateHash"]),
                    _snapshot(cash_entries=[first_opening, second_opening]),
                    password2,
                )
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/restore/commit",
                    body=invalid_accounting_body,
                    token=token2,
                )
                _expect("invalid duplicate cash openings rejected", status, 400)

                invalid_reminder = _settlement_row()
                invalid_reminder["data"]["reminderPlan"] = {"rules": "not-a-list"}
                invalid_reminder_body = _restore_body(
                    "7" * 32,
                    workspace2,
                    str(state2["stateHash"]),
                    _snapshot(
                        people=[_person_row("person-new", "New")],
                        settlements=[invalid_reminder],
                    ),
                    password2,
                )
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/restore/commit",
                    body=invalid_reminder_body,
                    token=token2,
                )
                _expect("malformed reminder plan rejected", status, 400)

                status, shared = _request(
                    base_url,
                    "POST",
                    "/api/collections/zar_workspaces/records",
                    body={"displayName": "shared", "members": [user2, user1]},
                    token=token2,
                )
                _expect("shared workspace test setup", status, 200)
                status, _ = _request(
                    base_url,
                    "PATCH",
                    f"/api/collections/users/records/{user2}",
                    body={"workspace": str(shared["id"])},
                    token=token2,
                )
                _expect("shared workspace pin", status, 200)
                status, _ = _request(
                    base_url, "GET", "/api/zar/restore/state", token=token2
                )
                _expect("multi-member destructive restore denied", status, 403)
            except Exception:
                log.flush()
                details = log_path.read_text(encoding="utf-8", errors="replace")
                if details:
                    safe_details = details.encode("ascii", errors="backslashreplace").decode(
                        "ascii"
                    )
                    print("PocketBase log follows:\n" + safe_details)
                raise
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)

        recovery_database = root / "receipt-recovery.db"
        with (
            sqlite3.connect(data_dir / "data.db") as source,
            sqlite3.connect(recovery_database) as target,
        ):
            source.backup(target)
        recovery_report = root / "receipt-recovery-report.json"
        recovery = subprocess.run(
            [
                sys.executable,
                str(repository_root / "server" / "tools" / "verify_recovery_set.py"),
                "--pocketbase",
                str(pocketbase),
                "--database",
                str(recovery_database),
                "--migrations",
                str(migrations_dir),
                "--hooks",
                str(hooks_dir),
                "--report",
                str(recovery_report),
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=90,
        )
        if recovery.returncode != 0:
            raise AssertionError(
                "receipt-aware recovery verification failed:\n"
                + recovery.stdout
                + recovery.stderr
            )
        recovery_evidence = json.loads(recovery_report.read_text(encoding="utf-8"))
        before_receipts = recovery_evidence["pre_restore"]["restore_receipts"]
        after_receipts = recovery_evidence["post_restore"]["restore_receipts"]
        if (
            recovery_evidence["status"] != "pass"
            or before_receipts["count"] != 1
            or before_receipts != after_receipts
        ):
            raise AssertionError("receipt metadata did not reconcile during recovery")
        print("PASS receipt-aware isolated recovery and replay metadata reconciliation")

        down = subprocess.run(
            [
                str(pocketbase),
                "migrate",
                "down",
                "1",
                f"--dir={data_dir}",
                f"--migrationsDir={migrations_dir}",
            ],
            input="y\n",
            check=False,
            capture_output=True,
            text=True,
            timeout=60,
        )
        if down.returncode == 0:
            raise AssertionError("restore migration down unexpectedly removed receipts")
        with sqlite3.connect(data_dir / "data.db") as connection:
            migration_count = connection.execute(
                "SELECT count(*) FROM _migrations "
                "WHERE file = '1793604800_transactional_restore.js'"
            ).fetchone()[0]
            receipt_count = connection.execute(
                "SELECT count(*) FROM zar_restore_receipts"
            ).fetchone()[0]
        if migration_count != 1 or receipt_count != 1:
            raise AssertionError("failed restore rollback changed migration or receipts")
        print("PASS down migration refuses after a restore receipt exists")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pocketbase", required=True, type=Path)
    arguments = parser.parse_args()
    run(arguments.pocketbase.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
