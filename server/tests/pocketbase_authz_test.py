"""PocketBase authorization smoke tests using only the Python standard library.

The test starts a disposable PocketBase instance, applies the repository's real
migrations, and exercises the HTTP API as anonymous and normal member clients.
It never contacts production and never uses production data.
"""

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


def _migrate(
    pocketbase: Path,
    data_dir: Path,
    migrations_dir: Path,
    *arguments: str,
) -> None:
    result = subprocess.run(
        [
            str(pocketbase),
            "migrate",
            *arguments,
            f"--dir={data_dir}",
            f"--migrationsDir={migrations_dir}",
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"PocketBase migrate {' '.join(arguments)} failed:\n"
            f"{result.stdout}{result.stderr}"
        )
    print(f"PASS migration {' '.join(arguments)}")


def run(pocketbase: Path) -> None:
    if not pocketbase.is_file():
        raise FileNotFoundError(f"PocketBase binary not found: {pocketbase}")

    repository_root = Path(__file__).resolve().parents[2]
    source_migrations = repository_root / "server" / "pb_migrations"
    port = _free_port()
    base_url = f"http://127.0.0.1:{port}"

    with tempfile.TemporaryDirectory(
        prefix="zar-pocketbase-authz-",
        ignore_cleanup_errors=True,
    ) as temp:
        temp_root = Path(temp)
        data_dir = temp_root / "pb_data"
        migrations_dir = temp_root / "pb_migrations"
        log_path = temp_root / "pocketbase.log"
        shutil.copytree(source_migrations, migrations_dir)

        _migrate(pocketbase, data_dir, migrations_dir, "up")
        _migrate(pocketbase, data_dir, migrations_dir, "down", "2")
        _migrate(pocketbase, data_dir, migrations_dir, "up")

        with log_path.open("w", encoding="utf-8") as log:
            process = subprocess.Popen(
                [
                    str(pocketbase),
                    "serve",
                    f"--http=127.0.0.1:{port}",
                    f"--dir={data_dir}",
                    f"--migrationsDir={migrations_dir}",
                ],
                cwd=repository_root,
                stdout=log,
                stderr=subprocess.STDOUT,
                text=True,
            )
            try:
                _wait_for_health(base_url, process)

                suffix = secrets.token_hex(8)
                email = f"authz-{suffix}@example.test"
                password = f"Staging-{suffix}-Aa1!"

                status, user = _request(
                    base_url,
                    "POST",
                    "/api/collections/users/records",
                    body={
                        "email": email,
                        "password": password,
                        "passwordConfirm": password,
                    },
                )
                _expect("public signup baseline", status, 200)
                user_id = str(user["id"])

                status, authentication = _request(
                    base_url,
                    "POST",
                    "/api/collections/users/auth-with-password",
                    body={"identity": email, "password": password},
                )
                _expect("normal user authentication", status, 200)
                token = str(authentication["token"])

                status, workspace = _request(
                    base_url,
                    "POST",
                    "/api/collections/zar_workspaces/records",
                    body={"displayName": "Authorization test", "members": [user_id]},
                    token=token,
                )
                _expect("member workspace create", status, 200)
                workspace_id = str(workspace["id"])
                record_path = (
                    f"/api/collections/zar_workspaces/records/{workspace_id}"
                )

                status, _ = _request(base_url, "GET", record_path, token=token)
                _expect("member workspace view", status, 200)

                status, _ = _request(
                    base_url,
                    "PATCH",
                    record_path,
                    body={"displayName": "Authorization test updated"},
                    token=token,
                )
                _expect("member workspace update", status, 200)

                status, _ = _request(base_url, "DELETE", record_path)
                _expect("anonymous workspace delete denied", status, 403)

                status, _ = _request(
                    base_url,
                    "DELETE",
                    record_path,
                    token=token,
                )
                _expect("member workspace delete denied", status, 403)

                status, _ = _request(base_url, "GET", record_path, token=token)
                _expect("workspace survives denied deletes", status, 200)

                cash_id = "cash00000000001"
                cash_path = f"/api/collections/zar_cash_entries/records/{cash_id}"
                cash_amount = {
                    "assetType": "currency",
                    "currency": {
                        "code": "TOMAN",
                        "minorUnits": 1000,
                        "minorUnitScale": 0,
                    },
                }
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/collections/zar_cash_entries/records",
                    body={
                        "id": cash_id,
                        "workspace": workspace_id,
                        "data": {
                            "id": cash_id,
                            "businessId": workspace_id,
                            "kind": "contribution",
                            "direction": "receive",
                            "amount": cash_amount,
                            "occurredAt": "2026-01-01T00:00:00.000Z",
                            "note": "Authorization test contribution",
                            "dealId": None,
                            "reversesId": None,
                            "countedQuantity": None,
                            "expectedQuantity": None,
                        },
                    },
                    token=token,
                )
                _expect("member cash entry create", status, 200)

                status, _ = _request(
                    base_url,
                    "PATCH",
                    cash_path,
                    body={"data": {"note": "Forbidden rewrite"}},
                    token=token,
                )
                _expect("member cash entry update denied", status, 403)

                status, _ = _request(base_url, "DELETE", cash_path)
                _expect("anonymous cash entry delete denied", status, 403)

                status, _ = _request(
                    base_url,
                    "DELETE",
                    cash_path,
                    token=token,
                )
                _expect("member cash entry delete denied", status, 403)

                status, _ = _request(base_url, "GET", cash_path, token=token)
                _expect("cash entry survives denied mutations", status, 200)

                reversal_id = "cash00000000002"
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/collections/zar_cash_entries/records",
                    body={
                        "id": reversal_id,
                        "workspace": workspace_id,
                        "data": {
                            "id": reversal_id,
                            "businessId": workspace_id,
                            "kind": "reversal",
                            "direction": "deliver",
                            "amount": cash_amount,
                            "occurredAt": "2026-01-02T00:00:00.000Z",
                            "note": "Authorization test reversal",
                            "dealId": None,
                            "reversesId": cash_id,
                            "countedQuantity": None,
                            "expectedQuantity": None,
                        },
                    },
                    token=token,
                )
                _expect("member reversal create remains allowed", status, 200)
            except Exception:
                log.flush()
                details = log_path.read_text(encoding="utf-8", errors="replace")
                if details:
                    print("PocketBase log follows:\n" + details)
                raise
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--pocketbase",
        required=True,
        type=Path,
        help="Path to the PocketBase 0.40.4 executable",
    )
    arguments = parser.parse_args()
    run(arguments.pocketbase.resolve())


if __name__ == "__main__":
    main()
