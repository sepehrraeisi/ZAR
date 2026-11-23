"""Disposable tests for atomic / idempotent workspace bootstrap."""

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


def run(pocketbase: Path) -> None:
    repo = Path(__file__).resolve().parents[2]
    port = _free_port()
    base_url = f"http://127.0.0.1:{port}"
    with tempfile.TemporaryDirectory(prefix="zar-bootstrap-") as tmp:
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
                email = f"boot-{secrets.token_hex(4)}@example.test"
                password = f"Boot-{secrets.token_hex(4)}-Aa1!"
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
                _expect("signup", status, 200)
                user_id = str(user["id"])
                status, auth = _request(
                    base_url,
                    "POST",
                    "/api/collections/users/auth-with-password",
                    body={"identity": email, "password": password},
                )
                _expect("auth", status, 200)
                token = str(auth["token"])

                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/collections/zar_workspaces/records",
                    body={"displayName": "bypass", "members": [user_id]},
                    token=token,
                )
                _expect("record api create denied", status, 403)

                status, first = _request(
                    base_url,
                    "POST",
                    "/api/zar/bootstrap/workspace",
                    body={"displayName": "ZAR+"},
                    token=token,
                )
                _expect("bootstrap create", status, 200)
                workspace_id = str(first.get("workspaceId") or "")
                expected_id = f"ws{user_id}"
                if workspace_id != expected_id:
                    raise AssertionError(
                        f"expected deterministic id {expected_id}, got {workspace_id}"
                    )
                if first.get("created") is not True:
                    raise AssertionError(f"expected created=true: {first}")
                if first.get("pinned") is not True:
                    raise AssertionError(f"expected pinned=true: {first}")
                print("PASS deterministic workspace id")

                status, user_after = _request(
                    base_url,
                    "GET",
                    f"/api/collections/users/records/{user_id}",
                    token=token,
                )
                _expect("user fetch", status, 200)
                if user_after.get("workspace") != workspace_id:
                    raise AssertionError(f"user not pinned: {user_after}")
                print("PASS user pinned")

                status, replay = _request(
                    base_url,
                    "POST",
                    "/api/zar/bootstrap/workspace",
                    body={"displayName": "ZAR+"},
                    token=token,
                )
                _expect("bootstrap replay", status, 200)
                if replay.get("workspaceId") != workspace_id:
                    raise AssertionError(f"replay workspace mismatch: {replay}")
                if replay.get("created") is not False:
                    raise AssertionError(f"expected created=false on replay: {replay}")
                print("PASS idempotent bootstrap replay")

                status, listed = _request(
                    base_url,
                    "GET",
                    "/api/collections/zar_workspaces/records?perPage=50",
                    token=token,
                )
                _expect("list workspaces", status, 200)
                items = listed.get("items") if isinstance(listed, dict) else None
                if not isinstance(items, list) or len(items) != 1:
                    raise AssertionError(f"expected exactly one workspace: {listed}")
                print("PASS no duplicate workspaces")
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
