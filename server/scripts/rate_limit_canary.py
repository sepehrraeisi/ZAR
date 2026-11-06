#!/usr/bin/env python3
"""Exercise the ZAR PocketBase rate-limit policy against a disposable clone.

The script creates only clone-scoped synthetic records. It never prints or
writes generated credentials or auth tokens. The caller is responsible for
binding the clone to loopback and deleting the clone after archiving evidence.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import secrets
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path
from typing import Any


class CanaryFailure(RuntimeError):
    pass


def request(
    base_url: str,
    method: str,
    path: str,
    *,
    ip: str,
    body: Any | None = None,
    token: str | None = None,
    timeout: float = 20.0,
) -> tuple[int, Any | None]:
    payload = None if body is None else json.dumps(body).encode("utf-8")
    headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-Zar-Client-IP": ip,
    }
    if token:
        headers["Authorization"] = token
    req = urllib.request.Request(
        base_url.rstrip("/") + path,
        data=payload,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            raw = response.read()
            status = response.status
    except urllib.error.HTTPError as error:
        raw = error.read()
        status = error.code
    except Exception as error:  # pragma: no cover - integration-only detail
        raise CanaryFailure(f"request failed for {method} {path}: {error}") from error

    if not raw:
        return status, None
    try:
        return status, json.loads(raw)
    except json.JSONDecodeError:
        return status, None


def expect_status(actual: int, expected: int, label: str) -> None:
    if actual != expected:
        raise CanaryFailure(f"{label}: expected HTTP {expected}, got {actual}")


def expect_not_429(actual: int, label: str) -> None:
    if actual == 429:
        raise CanaryFailure(f"{label}: reached rate limit before documented boundary")


def boundary(
    base_url: str,
    *,
    label: str,
    method: str,
    path: str,
    ip: str,
    allowed: int,
    body: Any | None = None,
    token: str | None = None,
) -> dict[str, Any]:
    statuses: list[int] = []
    for index in range(allowed):
        status, _ = request(
            base_url,
            method,
            path,
            ip=ip,
            body=body,
            token=token,
        )
        expect_not_429(status, f"{label} request {index + 1}")
        statuses.append(status)
    limited, _ = request(
        base_url,
        method,
        path,
        ip=ip,
        body=body,
        token=token,
    )
    expect_status(limited, 429, f"{label} boundary")
    return {"pre_boundary": statuses, "limited": limited}


def people_requests(
    workspace_id: str,
    *,
    prefix: str,
    count: int,
) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for index in range(count):
        record_id = f"{prefix}{index:012d}"
        result.append(
            {
                "method": "POST",
                "url": "/api/collections/zar_people/records",
                "body": {
                    "id": record_id,
                    "workspace": workspace_id,
                    "data": {"id": record_id, "displayName": "rate probe"},
                },
            }
        )
    return result


def workspace_people_count(
    base_url: str,
    *,
    workspace_id: str,
    token: str,
    ip: str,
) -> int:
    query = urllib.parse.urlencode(
        {"page": "1", "perPage": "1", "filter": f"workspace='{workspace_id}'"}
    )
    status, response = request(
        base_url,
        "GET",
        f"/api/collections/zar_people/records?{query}",
        ip=ip,
        token=token,
    )
    expect_status(status, 200, "workspace people count")
    if not isinstance(response, dict) or not isinstance(response.get("totalItems"), int):
        raise CanaryFailure("workspace people count response is malformed")
    return response["totalItems"]


def wait_for_fresh_second() -> None:
    deadline = time.monotonic() + 2.0
    while time.monotonic() < deadline:
        if time.time() % 1.0 < 0.06:
            return
        time.sleep(0.003)
    raise CanaryFailure("could not align the outer-batch boundary probe")


def outer_batch_boundary(base_url: str, *, token: str, ip: str) -> dict[str, Any]:
    wait_for_fresh_second()
    barrier = threading.Barrier(11)

    def one_request() -> int:
        barrier.wait(timeout=3.0)
        status, _ = request(
            base_url,
            "POST",
            "/api/batch",
            ip=ip,
            token=token,
            body={"requests": []},
        )
        return status

    with concurrent.futures.ThreadPoolExecutor(max_workers=11) as pool:
        statuses = list(pool.map(lambda _: one_request(), range(11)))
    limited = statuses.count(429)
    if limited != 1 or len(statuses) - limited != 10:
        raise CanaryFailure(
            "outer batch boundary expected ten accepted-by-limiter and one 429, "
            f"got statuses {sorted(statuses)}"
        )
    return {"statuses": sorted(statuses), "limited": limited}


def run(base_url: str) -> dict[str, Any]:
    evidence: dict[str, Any] = {
        "policy": "1793437200_enable_rate_limits.js",
        "started_at_unix": int(time.time()),
        "result": "running",
    }

    # Clone-only identity; values are deliberately never added to evidence.
    email = f"rate-canary-{uuid.uuid4().hex}@example.test"
    password = secrets.token_urlsafe(24)
    setup_ip = "198.51.100.1"

    status, created = request(
        base_url,
        "POST",
        "/api/collections/users/records",
        ip=setup_ip,
        body={"email": email, "password": password, "passwordConfirm": password},
    )
    expect_status(status, 200, "clone user creation")
    if not isinstance(created, dict) or not isinstance(created.get("id"), str):
        raise CanaryFailure("clone user creation response is malformed")
    user_id = created["id"]

    status, authenticated = request(
        base_url,
        "POST",
        "/api/collections/users/auth-with-password",
        ip=setup_ip,
        body={"identity": email, "password": password},
    )
    expect_status(status, 200, "clone user authentication")
    if not isinstance(authenticated, dict) or not isinstance(
        authenticated.get("token"), str
    ):
        raise CanaryFailure("clone user authentication response is malformed")
    token = authenticated["token"]

    status, workspace = request(
        base_url,
        "POST",
        "/api/collections/zar_workspaces/records",
        ip=setup_ip,
        token=token,
        body={"displayName": "rate canary", "members": [user_id]},
    )
    expect_status(status, 200, "clone workspace creation")
    if not isinstance(workspace, dict) or not isinstance(workspace.get("id"), str):
        raise CanaryFailure("clone workspace response is malformed")
    workspace_id = workspace["id"]
    status, _ = request(
        base_url,
        "PATCH",
        f"/api/collections/users/records/{user_id}",
        ip=setup_ip,
        token=token,
        body={"workspace": workspace_id},
    )
    expect_status(status, 200, "clone workspace assignment")
    evidence["clone_setup"] = "pass"

    invalid_auth = {"identity": "missing@example.test", "password": "invalid-pass"}
    evidence["auth_boundary"] = boundary(
        base_url,
        label="authentication",
        method="POST",
        path="/api/collections/users/auth-with-password",
        ip="198.51.100.10",
        allowed=5,
        body=invalid_auth,
    )
    other_ip, _ = request(
        base_url,
        "POST",
        "/api/collections/users/auth-with-password",
        ip="198.51.100.11",
        body=invalid_auth,
    )
    expect_not_429(other_ip, "independent client IP")
    evidence["independent_ip_status"] = other_ip

    evidence["signup_boundary"] = boundary(
        base_url,
        label="signup",
        method="POST",
        path="/api/collections/users/records",
        ip="198.51.100.20",
        allowed=5,
        body={},
    )

    request_routes = [
        ("password_reset", "/request-password-reset", {"email": "none@example.test"}, None),
        ("otp", "/request-otp", {"email": "none@example.test"}, None),
        ("verification", "/request-verification", {"email": "none@example.test"}, None),
        ("email_change", "/request-email-change", {}, token),
    ]
    for offset, (name, suffix, payload, route_token) in enumerate(request_routes):
        evidence[f"{name}_request_boundary"] = boundary(
            base_url,
            label=f"{name} request",
            method="POST",
            path=f"/api/collections/users{suffix}",
            ip=f"198.51.100.{30 + offset}",
            allowed=3,
            body=payload,
            token=route_token,
        )

    confirm_routes = [
        ("password_reset", "/confirm-password-reset"),
        ("verification", "/confirm-verification"),
        ("email_change", "/confirm-email-change"),
    ]
    for offset, (name, suffix) in enumerate(confirm_routes):
        evidence[f"{name}_confirm_boundary"] = boundary(
            base_url,
            label=f"{name} confirmation",
            method="POST",
            path=f"/api/collections/users{suffix}",
            ip=f"198.51.100.{40 + offset}",
            allowed=10,
            body={},
        )

    guest_statuses: list[int] = []
    for index in range(60):
        guest_status, _ = request(
            base_url, "GET", "/api/health", ip="198.51.100.50"
        )
        expect_status(guest_status, 200, f"guest API request {index + 1}")
        guest_statuses.append(guest_status)
    guest_limited, _ = request(
        base_url, "GET", "/api/health", ip="198.51.100.50"
    )
    expect_status(guest_limited, 429, "guest API boundary")
    evidence["guest_api_boundary"] = {
        "pre_boundary_count": len(guest_statuses),
        "limited": guest_limited,
    }

    for index in range(61):
        auth_status, _ = request(
            base_url,
            "GET",
            "/api/health",
            ip="198.51.100.51",
            token=token,
        )
        expect_status(auth_status, 200, f"authenticated guest-bypass request {index + 1}")
    evidence["authenticated_guest_fallback_bypass"] = "pass"

    started = time.monotonic()
    status, _ = request(
        base_url,
        "POST",
        "/api/batch",
        ip="198.51.100.60",
        token=token,
        body={"requests": people_requests(workspace_id, prefix="rlp", count=500)},
        timeout=30.0,
    )
    expect_status(status, 200, "500-operation batch")
    evidence["batch_500"] = {
        "status": status,
        "elapsed_ms": round((time.monotonic() - started) * 1000),
        "reconciled_count": workspace_people_count(
            base_url,
            workspace_id=workspace_id,
            token=token,
            ip="198.51.100.61",
        ),
    }
    if evidence["batch_500"]["reconciled_count"] != 500:
        raise CanaryFailure("500-operation batch record reconciliation failed")

    rollback_id = "rlrollbackok01"
    mixed = people_requests(workspace_id, prefix="rlx", count=1)
    mixed[0]["body"]["id"] = rollback_id
    mixed[0]["body"]["data"]["id"] = rollback_id
    mixed.append(people_requests(workspace_id, prefix="rlp", count=1)[0])
    mixed_status, _ = request(
        base_url,
        "POST",
        "/api/batch",
        ip="198.51.100.62",
        token=token,
        body={"requests": mixed},
    )
    expect_status(mixed_status, 400, "invalid mixed batch")
    rollback_status, _ = request(
        base_url,
        "GET",
        f"/api/collections/zar_people/records/{rollback_id}",
        ip="198.51.100.63",
        token=token,
    )
    expect_status(rollback_status, 404, "mixed-batch atomic rollback")
    evidence["mixed_batch_rollback"] = {
        "batch_status": mixed_status,
        "rolled_back_record_status": rollback_status,
    }

    chunk_results: list[dict[str, int]] = []
    for chunk in range(2):
        started = time.monotonic()
        chunk_status, _ = request(
            base_url,
            "POST",
            "/api/batch",
            ip="198.51.100.64",
            token=token,
            body={
                "requests": people_requests(
                    workspace_id,
                    prefix=f"rq{chunk}",
                    count=400,
                )
            },
            timeout=30.0,
        )
        expect_status(chunk_status, 200, f"400-operation chunk {chunk + 1}")
        chunk_results.append(
            {
                "status": chunk_status,
                "elapsed_ms": round((time.monotonic() - started) * 1000),
            }
        )
    final_count = workspace_people_count(
        base_url,
        workspace_id=workspace_id,
        token=token,
        ip="198.51.100.65",
    )
    if final_count != 1300:
        raise CanaryFailure(f"sequential chunk reconciliation expected 1300, got {final_count}")
    evidence["sequential_400_chunks"] = {
        "chunks": chunk_results,
        "reconciled_count": final_count,
    }

    evidence["outer_batch_boundary"] = outer_batch_boundary(
        base_url, token=token, ip="198.51.100.70"
    )
    evidence["result"] = "pass"
    evidence["finished_at_unix"] = int(time.time())
    return evidence


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--evidence", required=True, type=Path)
    parser.add_argument(
        "--confirm-disposable-clone",
        action="store_true",
        required=True,
        help="Required acknowledgement that the loopback target is disposable.",
    )
    args = parser.parse_args()

    target = urllib.parse.urlsplit(args.base_url)
    if (
        target.scheme not in {"http", "https"}
        or target.hostname not in {"127.0.0.1", "localhost", "::1"}
        or target.username is not None
        or target.password is not None
        or target.path not in {"", "/"}
        or target.query
        or target.fragment
    ):
        parser.error(
            "--base-url must be a bare loopback URL; production and remote targets are refused"
        )

    evidence: dict[str, Any]
    try:
        evidence = run(args.base_url)
    except Exception as error:
        evidence = {
            "policy": "1793437200_enable_rate_limits.js",
            "result": "fail",
            "error_type": type(error).__name__,
            "error": str(error),
            "finished_at_unix": int(time.time()),
        }
        args.evidence.write_text(
            json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        raise

    args.evidence.write_text(
        json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
