"""Launch-readiness: signup rate-limit abuse evidence while prod stays closed.

Disposable PocketBase only: temporarily open users.createRule, burst anonymous
creates, assert the versioned users:create rate rule trips (429), then close
again. Production reopen still requires a forward migration + owner decision.
"""

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

from pocketbase_test_users import auth_superuser, ensure_superuser, _request

USERS_CREATE_RULE = {
    "label": "users:create",
    "audience": "",
    "duration": 600,
    "maxRequests": 5,
}


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


def _signup_body(email: str, password: str) -> dict[str, str]:
    return {
        "email": email,
        "password": password,
        "passwordConfirm": password,
    }


def run(pocketbase: Path) -> None:
    repo = Path(__file__).resolve().parents[2]
    port = _free_port()
    base_url = f"http://127.0.0.1:{port}"
    with tempfile.TemporaryDirectory(prefix="zar-signup-launch-abuse-") as tmp:
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
                admin_token = auth_superuser(base_url, super_password)

                status, settings = _request(
                    base_url,
                    "GET",
                    "/api/settings",
                    token=admin_token,
                )
                _expect("settings read", status, 200)
                rules = (
                    settings.get("rateLimits", {}).get("rules")
                    if isinstance(settings, dict)
                    else None
                )
                if not isinstance(rules, list) or USERS_CREATE_RULE not in rules:
                    raise AssertionError(
                        f"users:create rate rule missing or drifted: {rules}"
                    )
                print("PASS users:create rate rule present (5 / 600s)")

                status, probe = _request(
                    base_url,
                    "POST",
                    "/api/collections/users/records",
                    body=_signup_body(
                        f"probe-{secrets.token_hex(3)}@example.test",
                        f"Probe-{secrets.token_hex(4)}-Aa1!",
                    ),
                )
                if status not in (200, 403):
                    raise AssertionError(
                        f"pre-burst signup probe: expected 200 or 403, got {status}"
                    )
                print(f"PASS pre-burst signup probe: HTTP {status}")

                status, users_col = _request(
                    base_url,
                    "GET",
                    "/api/collections/users",
                    token=admin_token,
                )
                _expect("users collection read", status, 200)
                # Launch migration may already leave createRule public ("").
                # Otherwise temp-open for the burst, then always re-close.
                if users_col.get("createRule") not in (None, ""):
                    raise AssertionError(
                        "users.createRule unexpected start value "
                        f"{users_col.get('createRule')!r}"
                    )
                if users_col.get("createRule") != "":
                    status, opened = _request(
                        base_url,
                        "PATCH",
                        "/api/collections/users",
                        body={"createRule": ""},
                        token=admin_token,
                    )
                    _expect("temporary open users.createRule", status, 200)
                    if opened.get("createRule") != "":
                        raise AssertionError(
                            f"createRule not opened to public '': "
                            f"{opened.get('createRule')!r}"
                        )
                    print("PASS temporary open createRule on disposable instance")
                else:
                    print("PASS createRule already open (launch migration)")
                    opened = users_col

                password = f"Abuse-{secrets.token_hex(4)}-Aa1!"
                statuses: list[int] = []
                for index in range(8):
                    status, _ = _request(
                        base_url,
                        "POST",
                        "/api/collections/users/records",
                        body=_signup_body(
                            f"burst-{index}-{secrets.token_hex(3)}@example.test",
                            password,
                        ),
                    )
                    statuses.append(status)
                if 429 not in statuses:
                    raise AssertionError(
                        f"expected users:create rate limit 429 in burst, got {statuses}"
                    )
                if not any(code == 200 for code in statuses):
                    raise AssertionError(
                        f"expected some successful creates before 429, got {statuses}"
                    )
                print(f"PASS signup burst trips rate limit statuses={statuses}")

                status, _ = _request(
                    base_url,
                    "PATCH",
                    "/api/collections/users",
                    body={"createRule": None},
                    token=admin_token,
                )
                _expect("re-close users.createRule", status, 200)
                status, verify = _request(
                    base_url,
                    "GET",
                    "/api/collections/users",
                    token=admin_token,
                )
                _expect("users collection re-read after close", status, 200)
                if verify.get("createRule") is not None:
                    raise AssertionError(
                        "createRule still set after re-close: "
                        f"{verify.get('createRule')!r}"
                    )
                print("PASS createRule null after re-close")

                status, _ = _request(
                    base_url,
                    "POST",
                    "/api/collections/users/records",
                    body=_signup_body(
                        f"reclosed-{secrets.token_hex(3)}@example.test",
                        password,
                    ),
                )
                # Rate limiter may still answer 429 within the 600s window after the
                # burst; createRule closedness is proven by the GET above. Never 200.
                if status not in (403, 429):
                    raise AssertionError(
                        f"signup after re-close: expected 403 or 429, got {status}"
                    )
                print(f"PASS signup denied after re-close: HTTP {status}")
                print("PASS disposable instance re-closed")
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
