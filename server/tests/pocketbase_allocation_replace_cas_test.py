"""Disposable tests for atomic allocation replace CAS + idempotency."""

from __future__ import annotations

import argparse
import json
import secrets
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from pocketbase_test_users import ensure_superuser, signup_public_member


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
        base_url + path, data=payload, headers=headers, method=method
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            raw = response.read().decode("utf-8")
            return response.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as error:
        raw = error.read().decode("utf-8")
        try:
            decoded = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            decoded = {"raw": raw}
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
                f"PocketBase exited before becoming healthy (exit {process.returncode})"
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
        raise RuntimeError(
            f"PocketBase migrate up failed:\n{result.stdout}{result.stderr}"
        )


def run(pocketbase: Path) -> None:
    repo = Path(__file__).resolve().parents[2]
    port = _free_port()
    base_url = f"http://127.0.0.1:{port}"
    with tempfile.TemporaryDirectory(prefix="zar-alloc-cas-") as tmp:
        root = Path(tmp)
        data_dir = root / "pb_data"
        migrations_dir = root / "pb_migrations"
        hooks_dir = root / "pb_hooks"
        log_path = root / "pocketbase.log"
        shutil.copytree(repo / "server" / "pb_migrations", migrations_dir)
        shutil.copytree(repo / "server" / "pb_hooks", hooks_dir)
        _migrate(pocketbase, data_dir, migrations_dir)
        print("PASS migration up")
        ensure_superuser(pocketbase, data_dir)

        with log_path.open("w", encoding="utf-8") as log_file:
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
                cwd=str(repo),
                stdout=log_file,
                stderr=subprocess.STDOUT,
                text=True,
            )
            try:
                _wait_for_health(base_url, process)
                email = f"alloc-{secrets.token_hex(4)}@example.test"
                password = f"Alloc-{secrets.token_hex(4)}-Aa1!"
                user_id, token = signup_public_member(
                    base_url,
                    email=email,
                    password=password,
                )
                print("PASS public signup + auth: HTTP 200")
                status, workspace = _request(
                    base_url,
                    "POST",
                    "/api/zar/bootstrap/workspace",
                    body={"displayName": "Alloc CAS"},
                    token=token,
                )
                _expect("workspace", status, 200)
                workspace_id = str(workspace["workspaceId"])

                person_id = "p" + secrets.token_hex(6)
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_people",
                        "id": person_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": 0,
                        "idempotencyKey": secrets.token_hex(16),
                        "data": {
                            "id": person_id,
                            "displayName": "Alloc Person",
                            "phone": None,
                            "note": None,
                            "archived": False,
                            "createdAt": "2026-11-01T00:00:00.000Z",
                            "updatedAt": "2026-11-01T00:00:00.000Z",
                            "createdBy": user_id,
                        },
                    },
                    token=token,
                )
                _expect("person upsert", status, 200)

                settlement_id = "stlm" + secrets.token_hex(4)
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_settlements",
                        "id": settlement_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": 0,
                        "idempotencyKey": secrets.token_hex(16),
                        "data": {
                            "id": settlement_id,
                            "personId": person_id,
                            "dealId": None,
                            "direction": "receive",
                            "status": "open",
                            "amount": {
                                "assetType": "currency",
                                "currency": {
                                    "code": "TOMAN",
                                    "minorUnits": 1000,
                                    "minorUnitScale": 0,
                                },
                            },
                            "scheduledAt": "2026-11-01T00:00:00.000Z",
                            "hasTime": False,
                            "completedAt": None,
                            "note": None,
                            "createdAt": "2026-11-01T00:00:00.000Z",
                            "updatedAt": "2026-11-01T00:00:00.000Z",
                            "createdBy": user_id,
                        },
                    },
                    token=token,
                )
                _expect("settlement upsert", status, 200)

                key = secrets.token_hex(16)
                first_body = {
                    "workspaceId": workspace_id,
                    "settlementId": settlement_id,
                    "idempotencyKey": key,
                    "expectedBefore": [],
                    "allocations": [
                        {
                            "settlementId": settlement_id,
                            "targetType": "deal",
                            "targetId": "deal-one",
                            "amountToman": 400,
                        }
                    ],
                }
                status, first = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/allocations/replace",
                    body=first_body,
                    token=token,
                )
                _expect("alloc replace", status, 200)
                if first.get("replayed") is not False:
                    raise AssertionError(f"unexpected first replace: {first}")
                after = first.get("record", {}).get("after") or []
                if len(after) != 1:
                    raise AssertionError(f"expected one allocation row: {first}")
                print("PASS alloc replace wrote one row")

                status, replay = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/allocations/replace",
                    body=first_body,
                    token=token,
                )
                _expect("alloc replay", status, 200)
                if replay.get("replayed") is not True:
                    raise AssertionError(f"expected replayed receipt: {replay}")
                print("PASS alloc idempotent replay")

                status, stale = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/allocations/replace",
                    body={
                        "workspaceId": workspace_id,
                        "settlementId": settlement_id,
                        "idempotencyKey": secrets.token_hex(16),
                        "expectedBefore": [],
                        "allocations": [],
                    },
                    token=token,
                )
                _expect("stale alloc set rejected", status, 409)
                message = stale.get("message") if isinstance(stale, dict) else ""
                raw = message.rstrip(".") if isinstance(message, str) else ""
                details = json.loads(raw)
                if details.get("code") != "stale_allocation_set":
                    raise AssertionError(f"unexpected stale payload: {stale}")
                print("PASS stale allocation set rejected")

                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/collections/zar_allocations/records",
                    body={
                        "id": "alloc-bypass",
                        "workspace": workspace_id,
                        "data": {
                            "settlementId": settlement_id,
                            "targetType": "deal",
                            "targetId": "x",
                            "amountToman": 1,
                        },
                    },
                    token=token,
                )
                _expect("record api create denied", status, 403)
                print("PASS Record API create denied")
            finally:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pocketbase", required=True)
    args = parser.parse_args()
    run(Path(args.pocketbase).resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
