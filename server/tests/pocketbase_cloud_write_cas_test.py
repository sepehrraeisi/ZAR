"""Disposable tests for ordinary cloud-write CAS + idempotency.

Proves `/api/zar/write/upsert` rejects stale revisions with HTTP 409 and
replays an identical idempotency key without double-writing.
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


def _migrate(
    pocketbase: Path,
    data_dir: Path,
    migrations_dir: Path,
) -> None:
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
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"PocketBase migrate up failed:\n{result.stdout}{result.stderr}"
        )
    print("PASS migration up")


def run(pocketbase: Path) -> None:
    if not pocketbase.is_file():
        raise FileNotFoundError(f"PocketBase binary not found: {pocketbase}")

    repository_root = Path(__file__).resolve().parents[2]
    port = _free_port()
    base_url = f"http://127.0.0.1:{port}"

    with tempfile.TemporaryDirectory(
        prefix="zar-pocketbase-write-cas-",
        ignore_cleanup_errors=True,
    ) as temp:
        temp_root = Path(temp)
        data_dir = temp_root / "pb_data"
        migrations_dir = temp_root / "pb_migrations"
        hooks_dir = temp_root / "pb_hooks"
        log_path = temp_root / "pocketbase.log"
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

                suffix = secrets.token_hex(8)
                email = f"write-cas-{suffix}@example.test"
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
                    body={"displayName": "Write CAS test", "members": [user_id]},
                    token=token,
                )
                _expect("workspace create", status, 200)
                workspace_id = str(workspace["id"])

                person_id = f"p{suffix[:12]}"
                idem_key = secrets.token_hex(16)
                person_data = {
                    "id": person_id,
                    "displayName": "CAS Person",
                    "phone": None,
                    "note": "first",
                    "archived": False,
                    "createdAt": "2026-11-22T00:00:00.000Z",
                    "updatedAt": "2026-11-22T00:00:00.000Z",
                    "createdBy": user_id,
                }
                create_body = {
                    "collection": "zar_people",
                    "id": person_id,
                    "workspaceId": workspace_id,
                    "expectedRevision": 0,
                    "idempotencyKey": idem_key,
                    "data": person_data,
                }
                status, created = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body=create_body,
                    token=token,
                )
                _expect("cas create", status, 200)
                if created.get("revision") != 1 or created.get("replayed") is not False:
                    raise AssertionError(f"unexpected create payload: {created}")
                print("PASS cas create revision=1")

                status, replay = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body=create_body,
                    token=token,
                )
                _expect("idempotent replay", status, 200)
                if replay.get("replayed") is not True or replay.get("revision") != 1:
                    raise AssertionError(f"unexpected replay payload: {replay}")
                print("PASS idempotent replay")

                status, mismatch = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        **create_body,
                        "data": {**person_data, "note": "different"},
                    },
                    token=token,
                )
                _expect("idempotency payload mismatch", status, 409)
                print("PASS idempotency payload mismatch")

                update_key = secrets.token_hex(16)
                status, updated = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_people",
                        "id": person_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": 1,
                        "idempotencyKey": update_key,
                        "data": {**person_data, "note": "second", "updatedAt": "2026-11-22T01:00:00.000Z"},
                    },
                    token=token,
                )
                _expect("cas update", status, 200)
                if updated.get("revision") != 2:
                    raise AssertionError(f"unexpected update revision: {updated}")
                print("PASS cas update revision=2")

                stale_key = secrets.token_hex(16)
                status, stale = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_people",
                        "id": person_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": 1,
                        "idempotencyKey": stale_key,
                        "data": {**person_data, "note": "stale"},
                    },
                    token=token,
                )
                _expect("stale revision rejected", status, 409)
                message = stale.get("message") if isinstance(stale, dict) else ""
                # PocketBase appends a trailing period to ApiError messages.
                raw = message.rstrip(".") if isinstance(message, str) else ""
                try:
                    details = json.loads(raw) if raw else {}
                except json.JSONDecodeError as error:
                    raise AssertionError(f"stale conflict message not JSON: {stale}") from error
                if details.get("currentRevision") != 2 or details.get("code") != "stale_revision":
                    raise AssertionError(f"stale conflict missing currentRevision=2: {stale}")
                print("PASS stale revision currentRevision=2")

                status, fetched = _request(
                    base_url,
                    "GET",
                    f"/api/collections/zar_people/records/{person_id}",
                    token=token,
                )
                _expect("person fetch", status, 200)
                if int(fetched.get("revision", 0)) != 2:
                    raise AssertionError(f"stored revision mismatch: {fetched}")
                if fetched.get("data", {}).get("note") != "second":
                    raise AssertionError(f"stale write leaked: {fetched}")
                print("PASS stored record survived stale write")

                # Record API update without revision must fail closed.
                status, _ = _request(
                    base_url,
                    "PATCH",
                    f"/api/collections/zar_people/records/{person_id}",
                    body={"data": {**person_data, "note": "bypass"}},
                    token=token,
                )
                _expect("record api update without revision denied", status, 400)
                print("PASS record API requires revision")

            finally:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
                if process.returncode not in (0, None, -15, 1):
                    print(log_path.read_text(encoding="utf-8", errors="replace")[-4000:])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pocketbase", required=True)
    args = parser.parse_args()
    run(Path(args.pocketbase).resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
