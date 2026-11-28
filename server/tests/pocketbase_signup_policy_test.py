"""Public signup policy: open at launch (allow + rate-limit + admin seed)."""

from __future__ import annotations

import argparse
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
    auth_superuser,
    create_user_as_admin,
    ensure_superuser,
    _request,
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


def run(pocketbase: Path) -> None:
    repo = Path(__file__).resolve().parents[2]
    port = _free_port()
    base_url = f"http://127.0.0.1:{port}"
    with tempfile.TemporaryDirectory(prefix="zar-signup-policy-") as tmp:
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

                email = f"open-{secrets.token_hex(4)}@example.test"
                password = f"Open-{secrets.token_hex(4)}-Aa1!"
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
                _expect("public signup allowed", status, 200)
                print("PASS public signup create")

                # Additional creates may succeed or trip users:create 429.
                statuses = []
                for index in range(6):
                    status, _ = _request(
                        base_url,
                        "POST",
                        "/api/collections/users/records",
                        body={
                            "email": f"open-{index}-{secrets.token_hex(3)}@example.test",
                            "password": password,
                            "passwordConfirm": password,
                        },
                    )
                    statuses.append(status)
                    if status not in (200, 429):
                        raise AssertionError(
                            f"post-open create {index}: expected 200/429, got {status}"
                        )
                print(f"PASS public signup open burst statuses={statuses}")

                admin_token = auth_superuser(base_url, super_password)
                seed_email = f"seed-{secrets.token_hex(4)}@example.test"
                seed_password = f"Seed-{secrets.token_hex(4)}-Aa1!"
                user = create_user_as_admin(
                    base_url,
                    admin_token=admin_token,
                    email=seed_email,
                    password=seed_password,
                )
                print("PASS admin seed create")

                status, auth = _request(
                    base_url,
                    "POST",
                    "/api/collections/users/auth-with-password",
                    body={"identity": seed_email, "password": seed_password},
                )
                _expect("seeded user auth", status, 200)
                if str(auth.get("record", {}).get("id")) != str(user["id"]):
                    raise AssertionError("seeded auth user mismatch")
                print("PASS seeded user can sign in")

                status, boot = _request(
                    base_url,
                    "POST",
                    "/api/zar/bootstrap/workspace",
                    body={"displayName": "Signup Policy"},
                    token=str(auth["token"]),
                )
                _expect("bootstrap after seed", status, 200)
                if not boot.get("workspaceId"):
                    raise AssertionError(f"missing workspaceId: {boot}")
                print("PASS bootstrap after admin-seeded signup path")
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
