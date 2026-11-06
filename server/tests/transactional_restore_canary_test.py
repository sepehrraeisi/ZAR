"""Unit tests for the clone-only transactional restore canary."""

from __future__ import annotations

import importlib.util
import json
import os
import shutil
import socket
import stat
import subprocess
import tempfile
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "transactional_restore_canary.py"
SPEC = importlib.util.spec_from_file_location("transactional_restore_canary", SCRIPT)
if SPEC is None or SPEC.loader is None:  # pragma: no cover - import guard
    raise RuntimeError(f"could not load {SCRIPT}")
canary = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(canary)


def _clone_filesystem_fixture(root: Path) -> dict[str, Path]:
    server_root = root / "server"
    production_data = server_root / "pb_data"
    pocketbase = server_root / "pocketbase"
    work_root = server_root / "restore-clone.fixture"
    case_root = work_root / "case-canary"
    data = case_root / "pb_data"
    migrations = case_root / "pb_migrations"
    hooks = case_root / "pb_hooks"
    production_data.mkdir(parents=True)
    data.mkdir(parents=True)
    migrations.mkdir()
    hooks.mkdir()
    pocketbase.write_bytes(b"pocketbase fixture")
    for name in ("data.db", "auxiliary.db"):
        (production_data / name).write_bytes(f"production {name}".encode())
        (data / name).write_bytes(f"clone {name}".encode())
    return {
        "server_root": server_root,
        "production_data": production_data,
        "pocketbase": pocketbase,
        "work_root": work_root,
        "case_root": case_root,
        "data": data,
        "migrations": migrations,
        "hooks": hooks,
    }


def _clone_exec(
    fixture: dict[str, Path],
    *,
    executable: Path | None = None,
    data: Path | None = None,
    migrations: Path | None = None,
    hooks: Path | None = None,
) -> str:
    executable = fixture["pocketbase"] if executable is None else executable
    data = fixture["data"] if data is None else data
    migrations = fixture["migrations"] if migrations is None else migrations
    hooks = fixture["hooks"] if hooks is None else hooks
    return (
        f"{{ path={executable} ; argv[]={executable} serve "
        f"--http=127.0.0.1:18090 --dir={data} "
        f"--migrationsDir={migrations} --hooksDir={hooks} "
        "--hooksWatch=false ; ignore_errors=no ; }}"
    )


class _Backend:
    def __init__(self) -> None:
        self.identity = ""
        self.password = ""
        self.user_id = "cloneuser000001"
        self.workspace_id = "cloneworkspace1"
        self.tokens: set[str] = set()
        self.auth_count = 0
        self.committed = False
        self.commit_body: dict[str, Any] | None = None
        self.receipt: dict[str, Any] | None = None
        self.mismatch_replay = False
        self.error: str | None = None

    def token(self) -> str:
        self.auth_count += 1
        value = f"clone-token-{self.auth_count}"
        self.tokens.add(value)
        return value


class _Handler(BaseHTTPRequestHandler):
    server_version = "ZarCanaryFake/1"

    @property
    def backend(self) -> _Backend:
        return self.server.backend  # type: ignore[attr-defined,no-any-return]

    def log_message(self, format: str, *args: object) -> None:
        return

    def _body(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        value = json.loads(raw) if raw else {}
        if not isinstance(value, dict):
            raise ValueError("request body is not an object")
        return value

    def _authorized(self) -> bool:
        return self.headers.get("Authorization", "") in self.backend.tokens

    def _send(self, status: int, value: Any | None = None) -> None:
        payload = b"" if value is None else json.dumps(value).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if payload:
            self.wfile.write(payload)

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        if self.path == "/api/zar/restore/state":
            if not self._authorized():
                self._send(401, {"message": "unauthorized"})
                return
            counts = canary.EXPECTED_COUNTS if self.backend.committed else canary.EMPTY_COUNTS
            state_hash = "b" * 64 if self.backend.committed else "a" * 64
            self._send(
                200,
                {
                    "protocolVersion": 1,
                    "workspaceId": self.backend.workspace_id,
                    "stateHash": state_hash,
                    "counts": counts,
                },
            )
            return
        if self.path == "/api/collections/zar_restore_receipts/records":
            self._send(403, {"message": "private"})
            return
        self._send(404, {"message": "not found"})

    def do_PATCH(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        if self.path == f"/api/collections/users/records/{self.backend.user_id}":
            body = self._body()
            if not self._authorized() or body.get("workspace") != self.backend.workspace_id:
                self._send(403, {"message": "denied"})
                return
            self._send(200, {"id": self.backend.user_id})
            return
        self._send(404, {"message": "not found"})

    def do_POST(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        try:
            body = self._body()
            if self.path == "/api/collections/users/records":
                self.backend.identity = str(body.get("email", ""))
                self.backend.password = str(body.get("password", ""))
                if (
                    not self.backend.identity.endswith("@example.test")
                    or not self.backend.password
                    or body.get("passwordConfirm") != self.backend.password
                ):
                    self._send(400, {"message": "invalid synthetic user"})
                    return
                self._send(200, {"id": self.backend.user_id})
                return

            if self.path == "/api/collections/users/auth-with-password":
                if (
                    body.get("identity") != self.backend.identity
                    or body.get("password") != self.backend.password
                ):
                    self._send(400, {"message": "invalid credentials"})
                    return
                self._send(
                    200,
                    {
                        "token": self.backend.token(),
                        "record": {"id": self.backend.user_id},
                    },
                )
                return

            if self.path == "/api/collections/zar_workspaces/records":
                if not self._authorized() or body.get("members") != [self.backend.user_id]:
                    self._send(403, {"message": "denied"})
                    return
                self._send(200, {"id": self.backend.workspace_id})
                return

            if self.path == "/api/zar/restore/commit":
                if not self._authorized():
                    self._send(401, {"message": "unauthorized"})
                    return
                if not self.backend.committed:
                    snapshot = body.get("snapshot")
                    expected_collections = {
                        "people",
                        "deals",
                        "settlements",
                        "coinTypes",
                        "currencyTypes",
                        "paymentAllocations",
                        "cashEntries",
                    }
                    if (
                        body.get("protocolVersion") != 1
                        or body.get("businessId") != self.backend.workspace_id
                        or body.get("confirmationPassword") != self.backend.password
                        or body.get("expectedStateHash") != "a" * 64
                        or not isinstance(snapshot, dict)
                        or set(snapshot) != expected_collections
                        or any(not isinstance(snapshot[key], list) or len(snapshot[key]) != 1 for key in expected_collections)
                    ):
                        self._send(400, {"message": "invalid restore"})
                        return
                    self.backend.commit_body = body
                    self.backend.committed = True
                    self.backend.receipt = {
                        "protocolVersion": 1,
                        "requestId": body["requestId"],
                        "workspaceId": self.backend.workspace_id,
                        "snapshotHash": "b" * 64,
                        "beforeHash": "a" * 64,
                        "afterHash": "b" * 64,
                        "counts": canary.EXPECTED_COUNTS,
                        "committedAt": "2026-11-03T12:00:00.000Z",
                        "replayed": False,
                    }
                    self._send(200, self.backend.receipt)
                    return
                if body != self.backend.commit_body or self.backend.receipt is None:
                    self._send(409, {"message": "request changed"})
                    return
                replay = dict(self.backend.receipt)
                replay["replayed"] = True
                if self.backend.mismatch_replay:
                    replay["committedAt"] = "2026-11-03T12:01:00.000Z"
                self._send(200, replay)
                return

            self._send(404, {"message": "not found"})
        except Exception as error:  # pragma: no cover - failure diagnostic
            self.backend.error = type(error).__name__
            self._send(500, {"message": "fake server error"})


class _ReusableServer(ThreadingHTTPServer):
    allow_reuse_address = True
    daemon_threads = True


class _FakeService:
    def __init__(self) -> None:
        self.backend = _Backend()
        self.server: _ReusableServer | None = None
        self.thread: threading.Thread | None = None
        self.port = 0

    @property
    def base_url(self) -> str:
        return f"http://127.0.0.1:{self.port}"

    def start(self, port: int = 0) -> None:
        server = _ReusableServer(("127.0.0.1", port), _Handler)
        server.backend = self.backend  # type: ignore[attr-defined]
        self.server = server
        self.port = int(server.server_address[1])
        self.thread = threading.Thread(target=server.serve_forever, daemon=True)
        self.thread.start()

    def stop(self) -> None:
        if self.server is not None:
            self.server.shutdown()
            self.server.server_close()
        if self.thread is not None:
            self.thread.join(timeout=5)
        self.server = None
        self.thread = None

    def restart(self) -> None:
        port = self.port
        self.stop()
        self.start(port)

    def __enter__(self) -> "_FakeService":
        self.start()
        return self

    def __exit__(self, *_: object) -> None:
        self.stop()


class TransactionalRestoreCanaryTest(unittest.TestCase):
    def _verify_clone_fixture(
        self,
        fixture: dict[str, Path],
        service_exec: str,
    ) -> None:
        canary._verify_clone_exec_paths(
            service_exec,
            server_root=fixture["server_root"],
            production_data_dir=fixture["production_data"],
            expected_pocketbase=fixture["pocketbase"],
        )

    def test_clone_exec_paths_bind_one_real_disposable_tree(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = _clone_filesystem_fixture(Path(temporary).resolve())
            self._verify_clone_fixture(fixture, _clone_exec(fixture))

    def test_clone_exec_paths_refuse_traversal_and_wrong_peer_paths(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = _clone_filesystem_fixture(Path(temporary).resolve())
            nested = fixture["case_root"] / "nested"
            nested.mkdir()
            traversing_data = nested / ".." / "pb_data"
            with self.assertRaisesRegex(canary.CanaryError, "symlinks or traversal"):
                self._verify_clone_fixture(
                    fixture,
                    _clone_exec(fixture, data=traversing_data),
                )

            with self.assertRaisesRegex(canary.CanaryError, "approved disposable tree"):
                self._verify_clone_fixture(
                    fixture,
                    _clone_exec(
                        fixture,
                        migrations=fixture["production_data"],
                    ),
                )

            other_executable = fixture["server_root"] / "other-pocketbase"
            other_executable.write_bytes(b"unexpected executable")
            with self.assertRaisesRegex(canary.CanaryError, "expected PocketBase"):
                self._verify_clone_fixture(
                    fixture,
                    _clone_exec(fixture, executable=other_executable),
                )

    def test_clone_exec_paths_refuse_symlinked_clone_tree(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = _clone_filesystem_fixture(Path(temporary).resolve())
            alias = fixture["server_root"] / "restore-clone.alias"
            try:
                alias.symlink_to(fixture["work_root"], target_is_directory=True)
            except (OSError, NotImplementedError):
                self.skipTest("directory symlink creation is unavailable")
            with self.assertRaisesRegex(canary.CanaryError, "symlinks or traversal"):
                self._verify_clone_fixture(
                    fixture,
                    _clone_exec(
                        fixture,
                        data=alias / "case-canary" / "pb_data",
                        migrations=alias / "case-canary" / "pb_migrations",
                        hooks=alias / "case-canary" / "pb_hooks",
                    ),
                )

    def test_clone_exec_paths_refuse_production_database_inode(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = _clone_filesystem_fixture(Path(temporary).resolve())
            clone_database = fixture["data"] / "data.db"
            clone_database.unlink()
            try:
                os.link(fixture["production_data"] / "data.db", clone_database)
            except OSError:
                self.skipTest("hard-link creation is unavailable")
            with self.assertRaisesRegex(canary.CanaryError, "aliases production"):
                self._verify_clone_fixture(fixture, _clone_exec(fixture))

    def test_clone_exec_paths_refuse_cross_named_production_inode(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = _clone_filesystem_fixture(Path(temporary).resolve())
            clone_database = fixture["data"] / "data.db"
            clone_database.unlink()
            try:
                os.link(fixture["production_data"] / "auxiliary.db", clone_database)
            except OSError:
                self.skipTest("hard-link creation is unavailable")
            with self.assertRaisesRegex(canary.CanaryError, "aliases production"):
                self._verify_clone_fixture(fixture, _clone_exec(fixture))

    def test_clone_exec_paths_require_distinct_clone_databases(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = _clone_filesystem_fixture(Path(temporary).resolve())
            auxiliary = fixture["data"] / "auxiliary.db"
            auxiliary.unlink()
            try:
                os.link(fixture["data"] / "data.db", auxiliary)
            except OSError:
                self.skipTest("hard-link creation is unavailable")
            with self.assertRaisesRegex(canary.CanaryError, "distinct files"):
                self._verify_clone_fixture(fixture, _clone_exec(fixture))

    def test_commit_and_replay_are_sanitized_and_restart_safe(self) -> None:
        with tempfile.TemporaryDirectory() as temporary, _FakeService() as service:
            root = Path(temporary).resolve()
            state_path = root / "private-state.json"
            commit_path = root / "commit-evidence.json"
            replay_path = root / "replay-evidence.json"

            commit = canary.run_commit(
                service.base_url,
                state_path,
                commit_path,
                confirm_disposable_clone=True,
            )
            self.assertEqual(commit["action"], "commit")
            self.assertEqual(commit["receipt"]["replayed"], False)
            self.assertEqual(commit["receipt"]["counts"], canary.EXPECTED_COUNTS)
            self.assertEqual(service.backend.error, None)

            private = json.loads(state_path.read_text(encoding="utf-8"))
            commit_text = commit_path.read_text(encoding="utf-8")
            for secret in (
                private["identity"],
                private["password"],
                private["token"],
            ):
                self.assertNotIn(secret, commit_text)
            for forbidden_key in (
                '"identity"',
                '"password"',
                '"token"',
                '"requestBody"',
                '"confirmationPassword"',
                '"note"',
            ):
                self.assertNotIn(forbidden_key, commit_text)
            self.assertIn("snapshot", private["requestBody"])
            if os.name == "posix":
                self.assertEqual(stat.S_IMODE(state_path.stat().st_mode), 0o600)
                self.assertEqual(stat.S_IMODE(commit_path.stat().st_mode), 0o600)

            service.restart()
            replay = canary.run_replay(
                service.base_url,
                state_path,
                replay_path,
                confirm_disposable_clone=True,
            )
            self.assertEqual(replay["action"], "replay")
            self.assertEqual(replay["receipt"]["replayed"], True)
            original = dict(commit["receipt"])
            original["replayed"] = True
            self.assertEqual(replay["receipt"], original)
            self.assertGreaterEqual(service.backend.auth_count, 2)

            replay_text = replay_path.read_text(encoding="utf-8")
            for secret in (
                private["identity"],
                private["password"],
                private["token"],
            ):
                self.assertNotIn(secret, replay_text)
            self.assertNotIn('"requestBody"', replay_text)
            self.assertEqual(service.backend.error, None)

    def test_replay_receipt_metadata_mismatch_fails_without_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temporary, _FakeService() as service:
            root = Path(temporary).resolve()
            state_path = root / "private-state.json"
            canary.run_commit(
                service.base_url,
                state_path,
                root / "commit.json",
                confirm_disposable_clone=True,
            )
            service.backend.mismatch_replay = True
            service.restart()
            replay_path = root / "replay.json"

            with self.assertRaisesRegex(
                canary.CanaryError,
                "metadata differs",
            ):
                canary.run_replay(
                    service.base_url,
                    state_path,
                    replay_path,
                    confirm_disposable_clone=True,
                )
            self.assertFalse(replay_path.exists())

    def test_non_loopback_and_ambiguous_origins_are_refused(self) -> None:
        refused = (
            "https://127.0.0.1:8090",
            "http://127.0.0.1:8090",
            "http://127.0.0.1",
            "http://127.0.0.1:8090/path",
            "http://localhost:8090",
            "http://192.0.2.1:8090",
            "http://user:password@127.0.0.1:8090",
            "http://127.0.0.1:8090?redirect=http://example.test",
        )
        for value in refused:
            with self.subTest(value=value):
                with self.assertRaises(canary.CanaryError):
                    canary._normalize_base_url(
                        value,
                        confirm_disposable_clone=True,
                    )
        with self.assertRaisesRegex(canary.CanaryError, "confirmation"):
            canary._normalize_base_url(
                "http://127.0.0.1:18090",
                confirm_disposable_clone=False,
            )
        self.assertEqual(
            canary._normalize_base_url(
                "http://127.0.0.1:18090/",
                confirm_disposable_clone=True,
            ),
            "http://127.0.0.1:18090",
        )
        self.assertEqual(
            canary._normalize_base_url(
                "http://[::1]:18090",
                confirm_disposable_clone=True,
            ),
            "http://[::1]:18090",
        )

    def test_new_paths_must_be_absolute_distinct_and_absent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            existing = root / "existing.json"
            existing.write_text("{}", encoding="utf-8")
            with self.assertRaisesRegex(canary.CanaryError, "already exists"):
                canary.run_commit(
                    "http://127.0.0.1:1",
                    existing,
                    root / "new-output.json",
                    confirm_disposable_clone=True,
                )
            with self.assertRaisesRegex(canary.CanaryError, "already exists"):
                canary.run_commit(
                    "http://127.0.0.1:1",
                    root / "new-state.json",
                    existing,
                    confirm_disposable_clone=True,
                )
            with self.assertRaisesRegex(canary.CanaryError, "must be absolute"):
                canary.run_commit(
                    "http://127.0.0.1:1",
                    Path("relative-state.json"),
                    root / "new-output.json",
                    confirm_disposable_clone=True,
                )
            same = root / "same.json"
            with self.assertRaisesRegex(canary.CanaryError, "must be different"):
                canary.run_commit(
                    "http://127.0.0.1:1",
                    same,
                    same,
                    confirm_disposable_clone=True,
                )

    @unittest.skipUnless(os.name == "posix", "POSIX mode guard")
    def test_replay_refuses_non_private_state_mode(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            state_path = root / "private-state.json"
            state_path.write_text("{}", encoding="utf-8")
            state_path.chmod(0o644)
            with self.assertRaisesRegex(canary.CanaryError, "mode must be 0600"):
                canary.run_replay(
                    "http://127.0.0.1:1",
                    state_path,
                    root / "output.json",
                    confirm_disposable_clone=True,
                )

    def test_replay_refuses_symlink_state_when_supported(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            target = root / "target.json"
            target.write_text("{}", encoding="utf-8")
            link = root / "state-link.json"
            try:
                link.symlink_to(target)
            except (OSError, NotImplementedError):
                self.skipTest("symlink creation is unavailable")
            with self.assertRaisesRegex(canary.CanaryError, "non-symlink"):
                canary.run_replay(
                    "http://127.0.0.1:1",
                    link,
                    root / "output.json",
                    confirm_disposable_clone=True,
                )

    @unittest.skipUnless(
        os.environ.get("ZAR_POCKETBASE"),
        "set ZAR_POCKETBASE to run the real PocketBase restart test",
    )
    def test_real_pocketbase_commit_restart_and_replay(self) -> None:
        pocketbase = Path(os.environ["ZAR_POCKETBASE"]).resolve()
        self.assertTrue(pocketbase.is_file())
        repository = Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory(prefix="zar-canary-real-") as temporary:
            root = Path(temporary)
            data = root / "pb_data"
            migrations = root / "pb_migrations"
            hooks = root / "pb_hooks"
            shutil.copytree(repository / "server" / "pb_migrations", migrations)
            shutil.copytree(repository / "server" / "pb_hooks", hooks)
            migration = subprocess.run(
                [
                    str(pocketbase),
                    "migrate",
                    "up",
                    f"--dir={data}",
                    f"--migrationsDir={migrations}",
                ],
                check=False,
                capture_output=True,
                text=True,
                timeout=60,
            )
            self.assertEqual(
                migration.returncode,
                0,
                migration.stdout + migration.stderr,
            )
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
                listener.bind(("127.0.0.1", 0))
                port = int(listener.getsockname()[1])
            base_url = f"http://127.0.0.1:{port}"
            arguments = [
                str(pocketbase),
                "serve",
                f"--http=127.0.0.1:{port}",
                f"--dir={data}",
                f"--migrationsDir={migrations}",
                f"--hooksDir={hooks}",
                "--hooksWatch=false",
            ]
            creation_flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0

            def start() -> subprocess.Popen[bytes]:
                process = subprocess.Popen(
                    arguments,
                    cwd=repository,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    creationflags=creation_flags,
                )
                deadline = time.monotonic() + 30
                while time.monotonic() < deadline:
                    if process.poll() is not None:
                        self.fail(f"PocketBase exited with {process.returncode}")
                    try:
                        status, _ = canary._request(base_url, "GET", "/api/health")
                        if status == 200:
                            return process
                    except canary.CanaryError:
                        pass
                    time.sleep(0.2)
                process.kill()
                process.wait(timeout=5)
                self.fail("PocketBase did not become healthy")

            process = start()
            try:
                state_path = root / "private-state.json"
                commit_path = root / "commit.json"
                replay_path = root / "replay.json"
                commit = canary.run_commit(
                    base_url,
                    state_path,
                    commit_path,
                    confirm_disposable_clone=True,
                )
                process.terminate()
                process.wait(timeout=10)
                process = start()
                replay = canary.run_replay(
                    base_url,
                    state_path,
                    replay_path,
                    confirm_disposable_clone=True,
                )
                self.assertEqual(commit["receipt"]["snapshotHash"], replay["receipt"]["snapshotHash"])
                self.assertFalse(commit["receipt"]["replayed"])
                self.assertTrue(replay["receipt"]["replayed"])
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)


if __name__ == "__main__":
    unittest.main()
