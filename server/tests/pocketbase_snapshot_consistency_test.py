"""Consistent workspace snapshot read under concurrent writes (ZAR-DATA-006)."""

from __future__ import annotations

import argparse
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


def _person_data(person_id: str, note: str, actor_id: str) -> dict[str, Any]:
    return {
        "id": person_id,
        "displayName": "Snapshot Person",
        "phone": None,
        "note": note,
        "archived": False,
        "createdAt": "2026-11-23T00:00:00.000Z",
        "updatedAt": "2026-11-23T00:00:00.000Z",
        "createdBy": actor_id,
    }


def run(pocketbase: Path) -> None:
    repo = Path(__file__).resolve().parents[2]
    port = _free_port()
    base_url = f"http://127.0.0.1:{port}"
    with tempfile.TemporaryDirectory(prefix="zar-snapshot-consistency-") as tmp:
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

                status, _ = _request(base_url, "GET", "/api/zar/read/snapshot")
                _expect("anonymous snapshot denied", status, 401)

                email = f"snap-{secrets.token_hex(4)}@example.test"
                password = f"Snap-{secrets.token_hex(4)}-Aa1!"
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
                    body={"displayName": "Snapshot Consistency"},
                    token=token,
                )
                _expect("workspace bootstrap", status, 200)
                workspace_id = str(boot["workspaceId"])

                person_id = "p" + secrets.token_hex(6)
                status, created = _request(
                    base_url,
                    "POST",
                    "/api/zar/write/upsert",
                    body={
                        "collection": "zar_people",
                        "id": person_id,
                        "workspaceId": workspace_id,
                        "expectedRevision": 0,
                        "idempotencyKey": secrets.token_hex(16),
                        "data": _person_data(person_id, "before", user_id),
                    },
                    token=token,
                )
                _expect("person seed", status, 200)
                if created.get("revision") != 1:
                    raise AssertionError(f"unexpected seed revision: {created}")

                status, snap = _request(
                    base_url,
                    "GET",
                    "/api/zar/read/snapshot",
                    token=token,
                )
                _expect("snapshot after seed", status, 200)
                if snap.get("workspaceId") != workspace_id:
                    raise AssertionError(f"workspace mismatch: {snap}")
                epoch_after_seed = int(snap.get("epoch", -1))
                if epoch_after_seed < 1:
                    raise AssertionError(f"epoch should advance on write: {snap}")
                people = snap.get("people") or []
                if len(people) != 1 or people[0].get("data", {}).get("note") != "before":
                    raise AssertionError(f"unexpected seed snapshot people: {people}")
                if int(people[0].get("revision", 0)) != 1:
                    raise AssertionError(f"seed revision missing: {people}")
                print(f"PASS snapshot epoch after seed={epoch_after_seed}")

                stop = threading.Event()
                observed: list[dict[str, Any]] = []
                errors: list[BaseException] = []

                def reader() -> None:
                    try:
                        while not stop.is_set():
                            status_code, body = _request(
                                base_url,
                                "GET",
                                "/api/zar/read/snapshot",
                                token=token,
                            )
                            if status_code == 503:
                                continue
                            if status_code != 200:
                                raise AssertionError(
                                    f"reader unexpected HTTP {status_code}: {body}"
                                )
                            note = None
                            revision = None
                            for row in body.get("people") or []:
                                if row.get("id") == person_id:
                                    note = (row.get("data") or {}).get("note")
                                    revision = row.get("revision")
                                    break
                            # Wholly pre or post — never mixed markers.
                            if (note, revision) not in (
                                ("before", 1),
                                ("after", 2),
                            ):
                                raise AssertionError(
                                    f"mixed or unknown person state: note={note} "
                                    f"revision={revision} body={body}"
                                )
                            observed.append(
                                {
                                    "epoch": body.get("epoch"),
                                    "note": note,
                                    "revision": revision,
                                }
                            )
                    except BaseException as error:  # noqa: BLE001 - surface to main
                        errors.append(error)

                def writer() -> None:
                    try:
                        time.sleep(0.05)
                        status_code, body = _request(
                            base_url,
                            "POST",
                            "/api/zar/write/upsert",
                            body={
                                "collection": "zar_people",
                                "id": person_id,
                                "workspaceId": workspace_id,
                                "expectedRevision": 1,
                                "idempotencyKey": secrets.token_hex(16),
                                "data": _person_data(person_id, "after", user_id),
                            },
                            token=token,
                        )
                        if status_code != 200:
                            raise AssertionError(
                                f"concurrent write failed: {status_code} {body}"
                            )
                        # Keep writing briefly so the reader observes both epochs.
                        for _ in range(8):
                            time.sleep(0.03)
                            _request(
                                base_url,
                                "POST",
                                "/api/zar/write/upsert",
                                body={
                                    "collection": "zar_people",
                                    "id": person_id,
                                    "workspaceId": workspace_id,
                                    "expectedRevision": 1,
                                    "idempotencyKey": secrets.token_hex(16),
                                    "data": _person_data(
                                        person_id, "stale-race", user_id
                                    ),
                                },
                                token=token,
                            )
                    except BaseException as error:  # noqa: BLE001
                        errors.append(error)

                with ThreadPoolExecutor(max_workers=2) as pool:
                    futures = [pool.submit(reader), pool.submit(writer)]
                    futures[1].result(timeout=30)
                    stop.set()
                    futures[0].result(timeout=30)
                if errors:
                    raise errors[0]
                if len(observed) < 2:
                    raise AssertionError(f"reader collected too few snapshots: {observed}")
                notes = {item["note"] for item in observed}
                if "before" not in notes and "after" not in notes:
                    raise AssertionError(f"reader never saw domain notes: {observed}")
                print(f"PASS concurrent snapshots consistent count={len(observed)}")

                status, final = _request(
                    base_url,
                    "GET",
                    "/api/zar/read/snapshot",
                    token=token,
                )
                _expect("final snapshot", status, 200)
                final_epoch = int(final.get("epoch", -1))
                if final_epoch <= epoch_after_seed:
                    raise AssertionError(
                        f"epoch did not advance after concurrent write: "
                        f"seed={epoch_after_seed} final={final_epoch}"
                    )
                print(f"PASS epoch advanced seed={epoch_after_seed} final={final_epoch}")
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
