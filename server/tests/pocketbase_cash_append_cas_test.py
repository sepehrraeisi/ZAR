"""Disposable tests for cash journal append CAS + idempotency."""

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


def run(pocketbase: Path) -> None:
    repo = Path(__file__).resolve().parents[2]
    port = _free_port()
    base_url = f"http://127.0.0.1:{port}"
    with tempfile.TemporaryDirectory(prefix="zar-cash-cas-") as tmp:
        root = Path(tmp)
        data_dir = root / "pb_data"
        migrations_dir = root / "pb_migrations"
        hooks_dir = root / "pb_hooks"
        log_path = root / "pocketbase.log"
        shutil.copytree(repo / "server" / "pb_migrations", migrations_dir)
        shutil.copytree(repo / "server" / "pb_hooks", hooks_dir)
        _migrate(pocketbase, data_dir, migrations_dir)
        print("PASS migration up")

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
                email = f"cash-{secrets.token_hex(4)}@example.test"
                password = f"Cash-{secrets.token_hex(4)}-Aa1!"
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/collections/users/records",
                    body={
                        "email": email,
                        "password": password,
                        "passwordConfirm": password,
                    },
                )
                _expect("signup", status, 200)
                status, auth = _request(
                    base_url,
                    "POST",
                    "/api/collections/users/auth-with-password",
                    body={"identity": email, "password": password},
                )
                _expect("auth", status, 200)
                token = str(auth["token"])
                status, boot = _request(
                    base_url,
                    "POST",
                    "/api/zar/bootstrap/workspace",
                    body={"displayName": "Cash CAS"},
                    token=token,
                )
                _expect("workspace", status, 200)
                workspace_id = str(boot["workspaceId"])

                cash_id = "cash" + secrets.token_hex(5)
                data = _cash_data(cash_id, workspace_id, "first contribution")
                key = secrets.token_hex(16)
                body = {
                    "workspaceId": workspace_id,
                    "id": cash_id,
                    "idempotencyKey": key,
                    "data": data,
                }

                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/collections/zar_cash_entries/records",
                    body={"id": cash_id, "workspace": workspace_id, "data": data},
                    token=token,
                )
                _expect("record api create denied", status, 403)

                status, first = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/cash/append",
                    body=body,
                    token=token,
                )
                _expect("cash append", status, 200)
                if first.get("replayed") is not False:
                    raise AssertionError(f"unexpected first append: {first}")
                print("PASS cash append created")

                status, replay = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/cash/append",
                    body=body,
                    token=token,
                )
                _expect("cash replay", status, 200)
                if replay.get("replayed") is not True:
                    raise AssertionError(f"expected replayed receipt: {replay}")
                print("PASS cash idempotent replay")

                status, mismatch = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/cash/append",
                    body={
                        **body,
                        "data": _cash_data(cash_id, workspace_id, "changed note"),
                    },
                    token=token,
                )
                _expect("idempotency payload mismatch", status, 409)
                print("PASS idempotency payload mismatch")

                status, immutable = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/cash/append",
                    body={
                        "workspaceId": workspace_id,
                        "id": cash_id,
                        "idempotencyKey": secrets.token_hex(16),
                        "data": _cash_data(cash_id, workspace_id, "tamper"),
                    },
                    token=token,
                )
                _expect("immutable conflict", status, 409)
                message = immutable.get("message") if isinstance(immutable, dict) else ""
                raw = message.rstrip(".") if isinstance(message, str) else ""
                details = json.loads(raw)
                if details.get("code") != "cash_entry_immutable":
                    raise AssertionError(f"unexpected immutable payload: {immutable}")
                print("PASS cash entry immutable")
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
