"""PocketBase domain hard-delete invariant tests (standard library only).

Starts a disposable PocketBase instance against the repository's real
migrations and proves that workspace members and anonymous clients can no
longer hard-delete financial/history rows, while the client's atomic
allocation-replace flow keeps working.
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
        base_url + path, data=payload, headers=headers, method=method
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            raw = response.read().decode("utf-8")
            return response.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as error:
        raw = error.read().decode("utf-8")
        return error.code, (json.loads(raw) if raw else {})


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
        prefix="zar-pocketbase-hard-delete-",
        ignore_cleanup_errors=True,
    ) as temp:
        temp_root = Path(temp)
        data_dir = temp_root / "pb_data"
        migrations_dir = temp_root / "pb_migrations"
        log_path = temp_root / "pocketbase.log"
        shutil.copytree(source_migrations, migrations_dir)

        _migrate(pocketbase, data_dir, migrations_dir, "up")
        _migrate(pocketbase, data_dir, migrations_dir, "down", "1")
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
                email = f"hard-delete-{suffix}@example.test"
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
                _expect("member authentication", status, 200)
                token = str(authentication["token"])

                status, workspace = _request(
                    base_url,
                    "POST",
                    "/api/collections/zar_workspaces/records",
                    body={"displayName": "Hard delete test", "members": [user_id]},
                    token=token,
                )
                _expect("workspace create", status, 200)
                workspace_id = str(workspace["id"])

                person_id = f"person{suffix[:8]}1"
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/collections/zar_people/records",
                    body={
                        "id": person_id,
                        "workspace": workspace_id,
                        "data": {"name": "Test", "note": ""},
                    },
                    token=token,
                )
                _expect("person create", status, 200)

                deal_id = f"deal{suffix[:8]}1"
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/collections/zar_deals/records",
                    body={
                        "id": deal_id,
                        "workspace": workspace_id,
                        "data": {"kind": "test", "note": ""},
                    },
                    token=token,
                )
                _expect("deal create", status, 200)

                # invariant: financial/history rows survive delete attempts
                status, _ = _request(
                    base_url,
                    "DELETE",
                    f"/api/collections/zar_people/records/{person_id}",
                    token=token,
                )
                _expect("member person hard-delete denied", status, 403)

                status, _ = _request(
                    base_url,
                    "DELETE",
                    f"/api/collections/zar_deals/records/{deal_id}",
                    token=token,
                )
                _expect("member deal hard-delete denied", status, 403)

                status, _ = _request(
                    base_url,
                    "DELETE",
                    f"/api/collections/zar_people/records/{person_id}",
                )
                _expect("anonymous person hard-delete denied", status, 403)

                status, person = _request(
                    base_url,
                    "GET",
                    f"/api/collections/zar_people/records/{person_id}",
                    token=token,
                )
                _expect("person survives denied deletes", status, 200)

                status, settlement = _request(
                    base_url,
                    "POST",
                    "/api/collections/zar_settlements/records",
                    body={
                        "id": f"stlm{suffix[:8]}1",
                        "workspace": workspace_id,
                        "data": {"note": ""},
                    },
                    token=token,
                )
                _expect("settlement create", status, 200)
                settlement_id = str(settlement["id"])

                allocation_id = f"alloc{suffix[:8]}1"
                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/collections/zar_allocations/records",
                    body={
                        "id": allocation_id,
                        "workspace": workspace_id,
                        "data": {"settlementId": settlement_id},
                    },
                    token=token,
                )
                _expect("allocation create (client replace flow)", status, 200)

                status, _ = _request(
                    base_url,
                    "DELETE",
                    f"/api/collections/zar_allocations/records/{allocation_id}",
                    token=token,
                )
                _expect(
                    "allocation delete still allowed (client replace flow)",
                    status,
                    204,
                )
            finally:
                process.terminate()
                process.wait(timeout=15)

    print("PASS domain hard-delete invariant suite")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pocketbase", required=True, help="PocketBase binary path")
    arguments = parser.parse_args()
    run(Path(arguments.pocketbase))
