"""Concurrent two-device CAS soak for cloud write routes (§10.5 gate).

Simulates two sessions of the same workspace owner racing upserts,
allocation replaces, and cash appends. Acceptance: exactly one writer
wins a shared-revision race (200 vs 409); distinct cash appends both land.
"""

from __future__ import annotations

import argparse
import json
import secrets
import shutil
import socket
import subprocess
import tempfile
import threading
import time
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any

from pocketbase_test_users import (
    _request,
    auth_superuser,
    ensure_superuser,
    provision_member,
)


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind(("127.0.0.1", 0))
        return int(listener.getsockname()[1])


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


def _parse_conflict(payload: Any) -> dict[str, Any]:
    message = payload.get("message") if isinstance(payload, dict) else ""
    raw = message.rstrip(".") if isinstance(message, str) else ""
    try:
        details = json.loads(raw) if raw else {}
    except json.JSONDecodeError as error:
        raise AssertionError(f"conflict message not JSON: {payload}") from error
    if not isinstance(details, dict):
        raise AssertionError(f"conflict details not object: {payload}")
    return details


def _person_data(person_id: str, note: str, actor_id: str) -> dict[str, Any]:
    return {
        "id": person_id,
        "displayName": "Soak Person",
        "phone": None,
        "note": note,
        "archived": False,
        "createdAt": "2026-11-23T00:00:00.000Z",
        "updatedAt": "2026-11-23T00:00:00.000Z",
        "createdBy": actor_id,
    }


def _cash_data(cash_id: str, workspace_id: str, note: str) -> dict[str, Any]:
    return {
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
        "occurredAt": "2026-11-23T00:00:00.000Z",
        "note": note,
        "dealId": None,
        "reversesId": None,
        "countedQuantity": None,
        "expectedQuantity": None,
    }


def _race_two(
    label: str,
    left: tuple[str, dict[str, Any]],
    right: tuple[str, dict[str, Any]],
    *,
    base_url: str,
    path: str,
) -> tuple[tuple[int, Any], tuple[int, Any]]:
    """Fire two POSTs as concurrently as possible; return (left, right) results."""
    barrier = threading.Barrier(2)
    results: dict[str, tuple[int, Any]] = {}

    def worker(name: str, token: str, body: dict[str, Any]) -> None:
        barrier.wait(timeout=10)
        results[name] = _request(base_url, "POST", path, body=body, token=token)

    left_token, left_body = left
    right_token, right_body = right
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [
            pool.submit(worker, "left", left_token, left_body),
            pool.submit(worker, "right", right_token, right_body),
        ]
        for future in as_completed(futures):
            future.result()
    left_result = results["left"]
    right_result = results["right"]
    statuses = {left_result[0], right_result[0]}
    if statuses != {200, 409}:
        raise AssertionError(
            f"{label}: expected one 200 and one 409, got "
            f"left={left_result[0]} right={right_result[0]} "
            f"left_body={left_result[1]} right_body={right_result[1]}"
        )
    print(f"PASS {label}: concurrent race resolved 200/409")
    return left_result, right_result


def run(pocketbase: Path) -> None:
    repo = Path(__file__).resolve().parents[2]
    port = _free_port()
    base_url = f"http://127.0.0.1:{port}"
    with tempfile.TemporaryDirectory(prefix="zar-multi-device-soak-") as tmp:
        root = Path(tmp)
        data_dir = root / "pb_data"
        migrations_dir = root / "pb_migrations"
        hooks_dir = root / "pb_hooks"
        log_path = root / "pocketbase.log"
        shutil.copytree(repo / "server" / "pb_migrations", migrations_dir)
        shutil.copytree(repo / "server" / "pb_hooks", hooks_dir)
        _migrate(pocketbase, data_dir, migrations_dir)
        print("PASS migration up")
        super_password = ensure_superuser(pocketbase, data_dir)
        print("PASS superuser upsert")

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

                email = f"soak-{secrets.token_hex(4)}@example.test"
                password = f"Soak-{secrets.token_hex(4)}-Aa1!"
                admin_token = auth_superuser(base_url, super_password)
                user_id, token_a = provision_member(
                    base_url,
                    admin_token=admin_token,
                    email=email,
                    password=password,
                )
                # Second session for the same owner (= second device).
                status, auth_b = _request(
                    base_url,
                    "POST",
                    "/api/collections/users/auth-with-password",
                    body={"identity": email, "password": password},
                )
                _expect("device B auth", status, 200)
                token_b = str(auth_b["token"])

                status, boot = _request(
                    base_url,
                    "POST",
                    "/api/zar/bootstrap/workspace",
                    body={"displayName": "Multi Device Soak"},
                    token=token_a,
                )
                _expect("workspace bootstrap", status, 200)
                workspace_id = str(boot["workspaceId"])

                person_id = "p" + secrets.token_hex(6)
                create_body = {
                    "collection": "zar_people",
                    "id": person_id,
                    "workspaceId": workspace_id,
                    "expectedRevision": 0,
                    "idempotencyKey": secrets.token_hex(16),
                    "data": _person_data(person_id, "seed", user_id),
                }
                status, created = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body=create_body,
                    token=token_a,
                )
                _expect("person seed", status, 200)
                if created.get("revision") != 1:
                    raise AssertionError(f"unexpected seed revision: {created}")

                left_body = {
                    "collection": "zar_people",
                    "id": person_id,
                    "workspaceId": workspace_id,
                    "expectedRevision": 1,
                    "idempotencyKey": secrets.token_hex(16),
                    "data": _person_data(person_id, "device-a", user_id),
                }
                right_body = {
                    "collection": "zar_people",
                    "id": person_id,
                    "workspaceId": workspace_id,
                    "expectedRevision": 1,
                    "idempotencyKey": secrets.token_hex(16),
                    "data": _person_data(person_id, "device-b", user_id),
                }
                left, right = _race_two(
                    "person upsert race",
                    (token_a, left_body),
                    (token_b, right_body),
                    base_url=base_url,
                    path="/api/zar/write/upsert",
                )
                winner = left if left[0] == 200 else right
                loser = right if left[0] == 200 else left
                if winner[1].get("revision") != 2:
                    raise AssertionError(f"winner revision not 2: {winner[1]}")
                details = _parse_conflict(loser[1])
                if details.get("code") != "stale_revision":
                    raise AssertionError(f"loser missing stale_revision: {loser[1]}")
                if details.get("currentRevision") != 2:
                    raise AssertionError(
                        f"loser currentRevision expected 2: {loser[1]}"
                    )

                status, fetched = _request(
                    base_url,
                    "GET",
                    f"/api/collections/zar_people/records/{person_id}",
                    token=token_a,
                )
                _expect("person fetch after race", status, 200)
                note = fetched.get("data", {}).get("note")
                if note not in ("device-a", "device-b"):
                    raise AssertionError(f"unexpected surviving note: {fetched}")
                if int(fetched.get("revision", 0)) != 2:
                    raise AssertionError(f"stored revision not 2: {fetched}")
                print(f"PASS person race survivor note={note}")

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
                            "direction": "receive",
                            "status": "open",
                            "amount": {
                                "assetType": "currency",
                                "currency": {
                                    "code": "TOMAN",
                                    "minorUnits": 5000,
                                    "minorUnitScale": 0,
                                },
                            },
                            "scheduledAt": "2026-11-23T00:00:00.000Z",
                            "hasTime": False,
                            "createdAt": "2026-11-23T00:00:00.000Z",
                            "updatedAt": "2026-11-23T00:00:00.000Z",
                            "dealId": None,
                            "completedAt": None,
                            "note": None,
                            "createdBy": user_id,
                        },
                    },
                    token=token_a,
                )
                _expect("settlement seed", status, 200)

                alloc_left = {
                    "workspaceId": workspace_id,
                    "settlementId": settlement_id,
                    "idempotencyKey": secrets.token_hex(16),
                    "expectedBefore": [],
                    "allocations": [
                        {
                            "settlementId": settlement_id,
                            "targetType": "deal",
                            "targetId": "deal-a",
                            "amountToman": 100,
                        }
                    ],
                }
                alloc_right = {
                    "workspaceId": workspace_id,
                    "settlementId": settlement_id,
                    "idempotencyKey": secrets.token_hex(16),
                    "expectedBefore": [],
                    "allocations": [
                        {
                            "settlementId": settlement_id,
                            "targetType": "deal",
                            "targetId": "deal-b",
                            "amountToman": 200,
                        }
                    ],
                }
                left, right = _race_two(
                    "allocation replace race",
                    (token_a, alloc_left),
                    (token_b, alloc_right),
                    base_url=base_url,
                    path="/api/zar/write/allocations/replace",
                )
                loser = right if left[0] == 200 else left
                details = _parse_conflict(loser[1])
                if details.get("code") != "stale_allocation_set":
                    raise AssertionError(
                        f"alloc loser missing stale_allocation_set: {loser[1]}"
                    )
                print("PASS allocation race loser is recoverable stale set")

                cash_a = "cash" + secrets.token_hex(5)
                cash_b = "cash" + secrets.token_hex(5)
                barrier = threading.Barrier(2)
                cash_results: dict[str, tuple[int, Any]] = {}

                def cash_worker(name: str, token: str, cash_id: str, note: str) -> None:
                    barrier.wait(timeout=10)
                    cash_results[name] = _request(
                        base_url,
                        "POST",
                        "/api/zar/write/cash/append",
                        body={
                            "workspaceId": workspace_id,
                            "id": cash_id,
                            "idempotencyKey": secrets.token_hex(16),
                            "data": _cash_data(cash_id, workspace_id, note),
                        },
                        token=token,
                    )

                with ThreadPoolExecutor(max_workers=2) as pool:
                    futures = [
                        pool.submit(cash_worker, "a", token_a, cash_a, "device-a"),
                        pool.submit(cash_worker, "b", token_b, cash_b, "device-b"),
                    ]
                    for future in as_completed(futures):
                        future.result()
                if cash_results["a"][0] != 200 or cash_results["b"][0] != 200:
                    raise AssertionError(
                        f"distinct cash appends should both succeed: {cash_results}"
                    )
                print("PASS concurrent distinct cash appends both 200")

                status, listed = _request(
                    base_url,
                    "GET",
                    f"/api/collections/zar_cash_entries/records?filter=(workspace='{workspace_id}')&perPage=50",
                    token=token_a,
                )
                _expect("cash list", status, 200)
                ids = {item.get("id") for item in listed.get("items", [])}
                if cash_a not in ids or cash_b not in ids:
                    raise AssertionError(f"missing cash rows after race: {ids}")
                print("PASS both cash rows persisted")
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
