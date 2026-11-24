"""Server-side upsert domain invariants (ZAR-DATA-003 / lifecycle lock)."""

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


def _person(person_id: str, actor_id: str) -> dict[str, Any]:
    return {
        "id": person_id,
        "displayName": "Invariant Person",
        "phone": None,
        "note": None,
        "archived": False,
        "createdAt": "2026-11-23T00:00:00.000Z",
        "updatedAt": "2026-11-23T00:00:00.000Z",
        "createdBy": actor_id,
    }


def _deal(
    deal_id: str,
    person_id: str,
    actor_id: str,
    status: str = "active",
    *,
    amount: dict[str, Any] | None = None,
    pricing: Any = None,
) -> dict[str, Any]:
    return {
        "id": deal_id,
        "type": "buy",
        "personId": person_id,
        "amount": amount
        or {
            "assetType": "currency",
            "currency": {
                "code": "TOMAN",
                "minorUnits": 1000,
                "minorUnitScale": 0,
            },
        },
        "pricing": pricing,
        "dealAt": "2026-11-23T00:00:00.000Z",
        "status": status,
        "note": None,
        "createdBy": actor_id,
        "createdAt": "2026-11-23T00:00:00.000Z",
        "updatedAt": "2026-11-23T00:00:00.000Z",
    }


def _settlement(
    settlement_id: str,
    person_id: str,
    actor_id: str,
    *,
    status: str = "open",
    completed_at: str | None = None,
    amount: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "id": settlement_id,
        "personId": person_id,
        "dealId": None,
        "direction": "receive",
        "status": status,
        "amount": amount
        or {
            "assetType": "currency",
            "currency": {
                "code": "TOMAN",
                "minorUnits": 500,
                "minorUnitScale": 0,
            },
        },
        "scheduledAt": "2026-11-23T00:00:00.000Z",
        "hasTime": False,
        "completedAt": completed_at,
        "createdBy": actor_id,
        "createdAt": "2026-11-23T00:00:00.000Z",
        "updatedAt": "2026-11-23T00:00:00.000Z",
    }


def _conflict_code(payload: Any) -> str | None:
    message = payload.get("message") if isinstance(payload, dict) else ""
    raw = message.rstrip(".") if isinstance(message, str) else ""
    try:
        details = json.loads(raw) if raw else {}
    except json.JSONDecodeError:
        return None
    code = details.get("code")
    return code if isinstance(code, str) else None


def run(pocketbase: Path) -> None:
    repo = Path(__file__).resolve().parents[2]
    port = _free_port()
    base_url = f"http://127.0.0.1:{port}"
    with tempfile.TemporaryDirectory(prefix="zar-domain-invariants-") as tmp:
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
                email = f"inv-{secrets.token_hex(4)}@example.test"
                password = f"Inv-{secrets.token_hex(4)}-Aa1!"
                admin_token = auth_superuser(base_url, super_password)
                user_id, token = provision_member(
                    base_url,
                    admin_token=admin_token,
                    email=email,
                    password=password,
                )
                status, boot = _request(
                    base_url,
                    "POST",
                    "/api/zar/bootstrap/workspace",
                    body={"displayName": "Domain Invariants"},
                    token=token,
                )
                _expect("workspace", status, 200)
                workspace_id = str(boot["workspaceId"])

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
                            **_person(person_id, user_id),
                            "id": "other-id",
                        },
                    },
                    token=token,
                )
                _expect("person id mismatch denied", status, 400)

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
                            **_person(person_id, user_id),
                            "createdBy": "forged-actor",
                        },
                    },
                    token=token,
                )
                _expect("person forged createdBy denied", status, 400)

                legacy_person_id = "p" + secrets.token_hex(6)
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_people",
                        "id": legacy_person_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": 0,
                        "idempotencyKey": secrets.token_hex(16),
                        "data": _person(legacy_person_id, "local-user"),
                    },
                    token=token,
                )
                _expect("person legacy local-user create allowed", status, 200)

                status, created_person = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_people",
                        "id": person_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": 0,
                        "idempotencyKey": secrets.token_hex(16),
                        "data": _person(person_id, user_id),
                    },
                    token=token,
                )
                _expect("person create", status, 200)

                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_people",
                        "id": person_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": int(created_person["revision"]),
                        "idempotencyKey": secrets.token_hex(16),
                        "data": {
                            **_person(person_id, user_id),
                            "createdBy": "rewritten-actor",
                            "note": "mutated",
                        },
                    },
                    token=token,
                )
                _expect("person createdBy rewrite denied", status, 400)

                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_people",
                        "id": person_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": int(created_person["revision"]),
                        "idempotencyKey": secrets.token_hex(16),
                        "data": {
                            **_person(person_id, user_id),
                            "createdAt": "1999-01-01T00:00:00.000Z",
                            "note": "backdated",
                        },
                    },
                    token=token,
                )
                _expect("person createdAt rewrite denied", status, 400)

                deal_id = "d" + secrets.token_hex(6)
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_deals",
                        "id": deal_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": 0,
                        "idempotencyKey": secrets.token_hex(16),
                        "data": {
                            **_deal(deal_id, person_id, user_id),
                            "type": "purchase",
                        },
                    },
                    token=token,
                )
                _expect("deal bad type denied", status, 400)

                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_deals",
                        "id": deal_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": 0,
                        "idempotencyKey": secrets.token_hex(16),
                        "data": _deal(deal_id, "missing-person", user_id),
                    },
                    token=token,
                )
                _expect("deal missing person denied", status, 400)

                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_deals",
                        "id": deal_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": 0,
                        "idempotencyKey": secrets.token_hex(16),
                        "data": _deal(
                            deal_id,
                            person_id,
                            user_id,
                            amount={
                                "assetType": "currency",
                                "currency": {
                                    "code": "usd",
                                    "minorUnits": 1000,
                                    "minorUnitScale": 2,
                                },
                            },
                        ),
                    },
                    token=token,
                )
                _expect("deal lowercase currency code denied", status, 400)

                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_deals",
                        "id": deal_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": 0,
                        "idempotencyKey": secrets.token_hex(16),
                        "data": _deal(
                            deal_id,
                            person_id,
                            user_id,
                            amount={
                                "assetType": "currency",
                                "currency": {
                                    "code": "USD",
                                    "minorUnits": -5,
                                    "minorUnitScale": 2,
                                },
                            },
                        ),
                    },
                    token=token,
                )
                _expect("deal negative currency minor units denied", status, 400)

                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_deals",
                        "id": deal_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": 0,
                        "idempotencyKey": secrets.token_hex(16),
                        "data": _deal(
                            deal_id,
                            person_id,
                            user_id,
                            amount={
                                "assetType": "gold",
                                "gold": {
                                    "decimal": "1.5",
                                    "unit": "gram",
                                    "purity": "750",
                                },
                            },
                            pricing={
                                "kind": "currency",
                                "totalToman": {"wholeTomans": 1000},
                                "tomanPerUnit": "1",
                            },
                        ),
                    },
                    token=token,
                )
                _expect("deal pricing kind mismatch denied", status, 400)

                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_deals",
                        "id": deal_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": 0,
                        "idempotencyKey": secrets.token_hex(16),
                        "data": _deal(
                            deal_id,
                            person_id,
                            user_id,
                            amount={
                                "assetType": "coin",
                                "coinLines": [
                                    {
                                        "id": "line1",
                                        "coinTypeId": "missing-coin",
                                        "coinTypeNameSnapshot": "Ghost",
                                        "quantity": 1,
                                    }
                                ],
                            },
                            pricing={
                                "kind": "coin",
                                "totalToman": {"wholeTomans": 100},
                                "lines": [
                                    {
                                        "lineId": "line1",
                                        "method": "perPiece",
                                        "unitPriceToman": {"wholeTomans": 100},
                                        "rowTotalToman": {"wholeTomans": 100},
                                    }
                                ],
                            },
                        ),
                    },
                    token=token,
                )
                _expect("deal missing coin type denied", status, 400)

                status, created_deal = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_deals",
                        "id": deal_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": 0,
                        "idempotencyKey": secrets.token_hex(16),
                        "data": _deal(
                            deal_id, person_id, user_id, status="completed"
                        ),
                    },
                    token=token,
                )
                _expect("deal completed create", status, 200)

                status, locked = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_deals",
                        "id": deal_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": int(created_deal["revision"]),
                        "idempotencyKey": secrets.token_hex(16),
                        "data": _deal(
                            deal_id, person_id, user_id, status="active"
                        ),
                    },
                    token=token,
                )
                _expect("deal reopen denied", status, 409)
                if _conflict_code(locked) != "lifecycle_locked":
                    raise AssertionError(f"expected lifecycle_locked: {locked}")
                print("PASS deal terminal lifecycle locked")

                rewritten_deal = _deal(
                    deal_id, person_id, user_id, status="completed"
                )
                rewritten_deal["amount"] = {
                    "assetType": "currency",
                    "currency": {
                        "code": "TOMAN",
                        "minorUnits": 9999,
                        "minorUnitScale": 0,
                    },
                }
                status, field_locked = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_deals",
                        "id": deal_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": int(created_deal["revision"]),
                        "idempotencyKey": secrets.token_hex(16),
                        "data": rewritten_deal,
                    },
                    token=token,
                )
                _expect("deal terminal amount rewrite denied", status, 409)
                if _conflict_code(field_locked) != "terminal_field_locked":
                    raise AssertionError(
                        f"expected terminal_field_locked: {field_locked}"
                    )
                print("PASS deal terminal field freeze")

                note_only = _deal(
                    deal_id, person_id, user_id, status="completed"
                )
                note_only["note"] = "posted note ok"
                note_only["updatedAt"] = "2026-11-24T12:00:00.000Z"
                status, note_ok = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_deals",
                        "id": deal_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": int(created_deal["revision"]),
                        "idempotencyKey": secrets.token_hex(16),
                        "data": note_only,
                    },
                    token=token,
                )
                _expect("deal terminal note update", status, 200)
                created_deal = note_ok

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
                        "data": _settlement(
                            settlement_id,
                            person_id,
                            user_id,
                            status="completed",
                            completed_at=None,
                        ),
                    },
                    token=token,
                )
                _expect("settlement completed without completedAt denied", status, 400)

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
                        "data": _settlement(
                            settlement_id,
                            person_id,
                            user_id,
                            amount={
                                "assetType": "gold",
                                "gold": {
                                    "decimal": "bad",
                                    "unit": "gram",
                                    "purity": None,
                                },
                            },
                        ),
                    },
                    token=token,
                )
                _expect("settlement bad gold decimal denied", status, 400)

                status, created_st = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_settlements",
                        "id": settlement_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": 0,
                        "idempotencyKey": secrets.token_hex(16),
                        "data": _settlement(
                            settlement_id,
                            person_id,
                            user_id,
                            status="completed",
                            completed_at="2026-11-23T01:00:00.000Z",
                        ),
                    },
                    token=token,
                )
                _expect("settlement completed create", status, 200)

                status, st_locked = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_settlements",
                        "id": settlement_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": int(created_st["revision"]),
                        "idempotencyKey": secrets.token_hex(16),
                        "data": _settlement(
                            settlement_id, person_id, user_id, status="open"
                        ),
                    },
                    token=token,
                )
                _expect("settlement reopen denied", status, 409)
                if _conflict_code(st_locked) != "lifecycle_locked":
                    raise AssertionError(f"expected lifecycle_locked: {st_locked}")
                print("PASS settlement terminal lifecycle locked")

                rewritten_st = _settlement(
                    settlement_id,
                    person_id,
                    user_id,
                    status="completed",
                    completed_at="2026-11-23T01:00:00.000Z",
                )
                rewritten_st["direction"] = "deliver"
                status, st_field = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_settlements",
                        "id": settlement_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": int(created_st["revision"]),
                        "idempotencyKey": secrets.token_hex(16),
                        "data": rewritten_st,
                    },
                    token=token,
                )
                _expect("settlement terminal direction rewrite denied", status, 409)
                if _conflict_code(st_field) != "terminal_field_locked":
                    raise AssertionError(
                        f"expected terminal_field_locked: {st_field}"
                    )
                print("PASS settlement terminal field freeze")
                print("PASS amount/pricing/actor upsert parity")
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
