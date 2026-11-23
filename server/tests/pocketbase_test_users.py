"""Helpers to provision users when public signup is closed."""

from __future__ import annotations

import json
import secrets
import subprocess
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


_SUPER_EMAIL = "zar-test-super@zarplus.local"


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


def ensure_superuser(pocketbase: Path, data_dir: Path) -> str:
    """Upsert a disposable superuser; return its password."""
    password = f"Su-{secrets.token_hex(12)}-Aa1!"
    result = subprocess.run(
        [
            str(pocketbase),
            "superuser",
            "upsert",
            _SUPER_EMAIL,
            password,
            f"--dir={data_dir}",
        ],
        check=False,
        capture_output=True,
        text=True,
        timeout=60,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"superuser upsert failed:\n{result.stdout}{result.stderr}"
        )
    return password


def auth_superuser(base_url: str, password: str) -> str:
    status, auth = _request(
        base_url,
        "POST",
        "/api/collections/_superusers/auth-with-password",
        body={"identity": _SUPER_EMAIL, "password": password},
    )
    if status != 200 or not isinstance(auth, dict) or not auth.get("token"):
        raise RuntimeError(f"superuser auth failed: HTTP {status} {auth}")
    return str(auth["token"])


def create_user_as_admin(
    base_url: str,
    *,
    admin_token: str,
    email: str,
    password: str,
) -> dict[str, Any]:
    status, user = _request(
        base_url,
        "POST",
        "/api/collections/users/records",
        body={
            "email": email,
            "password": password,
            "passwordConfirm": password,
        },
        token=admin_token,
    )
    if status != 200 or not isinstance(user, dict) or not user.get("id"):
        raise RuntimeError(f"admin user create failed: HTTP {status} {user}")
    return user


def provision_member(
    base_url: str,
    *,
    admin_token: str,
    email: str,
    password: str,
) -> tuple[str, str]:
    """Create a member via admin token and return (user_id, member_auth_token).

    Call ensure_superuser() before `serve` so the data dir is not locked.
    """
    user = create_user_as_admin(
        base_url, admin_token=admin_token, email=email, password=password
    )
    status, auth = _request(
        base_url,
        "POST",
        "/api/collections/users/auth-with-password",
        body={"identity": email, "password": password},
    )
    if status != 200 or not isinstance(auth, dict) or not auth.get("token"):
        raise RuntimeError(f"member auth failed: HTTP {status} {auth}")
    return str(user["id"]), str(auth["token"])
