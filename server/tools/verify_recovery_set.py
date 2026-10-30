"""Verify a PocketBase recovery set without touching the source database.

The verifier copies a supplied data.db and migration directory into a
temporary directory, applies pending migrations with a supplied PocketBase
binary, starts the restored service on loopback, and proves that domain rows
are byte-logically unchanged. Reports contain counts and hashes, never row
payloads.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import socket
import sqlite3
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.parse import quote


DOMAIN_TABLES = (
    "zar_workspaces",
    "zar_people",
    "zar_deals",
    "zar_settlements",
    "zar_coin_types",
    "zar_currency_types",
    "zar_allocations",
    "zar_cash_entries",
)

JSON_COLUMNS = {
    "zar_workspaces": {"members"},
    "zar_people": {"data"},
    "zar_deals": {"data"},
    "zar_settlements": {"data"},
    "zar_coin_types": {"data"},
    "zar_currency_types": {"data"},
    "zar_allocations": {"data"},
    "zar_cash_entries": {"data"},
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _connect_read_only(database: Path) -> sqlite3.Connection:
    encoded = quote(database.resolve().as_posix(), safe="/:")
    connection = sqlite3.connect(
        f"file:{encoded}?mode=ro&immutable=1",
        uri=True,
    )
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA query_only = ON")
    return connection


def _canonical_json(value: Any) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )


def _table_snapshot(
    connection: sqlite3.Connection,
    table: str,
) -> tuple[int, str, list[dict[str, Any]]]:
    columns = [row["name"] for row in connection.execute(f'PRAGMA table_info("{table}")')]
    if not columns:
        raise ValueError(f"required table is missing: {table}")
    order = "id" if "id" in columns else columns[0]
    rows: list[dict[str, Any]] = []
    for source in connection.execute(f'SELECT * FROM "{table}" ORDER BY "{order}"'):
        row: dict[str, Any] = {}
        for column in columns:
            value = source[column]
            if column in JSON_COLUMNS[table] and value is not None:
                try:
                    value = json.loads(value)
                except (TypeError, json.JSONDecodeError) as error:
                    raise ValueError(f"{table}.{column} contains invalid JSON") from error
            elif isinstance(value, bytes):
                value = value.hex()
            row[column] = value
        rows.append(row)
    digest = hashlib.sha256(_canonical_json(rows).encode("utf-8")).hexdigest()
    return len(rows), digest, rows


def _reference_error(
    errors: list[str],
    *,
    source: str,
    reference: Any,
    targets: dict[str, str],
    workspace: str,
) -> None:
    if reference in (None, ""):
        return
    if not isinstance(reference, str) or reference not in targets:
        errors.append(f"{source} references a missing record")
    elif targets[reference] != workspace:
        errors.append(f"{source} crosses a workspace boundary")


def _validate_domain(rows: dict[str, list[dict[str, Any]]]) -> list[str]:
    errors: list[str] = []
    workspace_ids = {str(row["id"]) for row in rows["zar_workspaces"]}
    if not workspace_ids:
        errors.append("no workspace record exists")

    for row in rows["zar_workspaces"]:
        if not isinstance(row.get("members"), list):
            errors.append("zar_workspaces.members is not a JSON array")

    payloads: dict[str, dict[str, dict[str, Any]]] = {}
    workspaces: dict[str, dict[str, str]] = {}
    for table in DOMAIN_TABLES[1:]:
        payloads[table] = {}
        workspaces[table] = {}
        for row in rows[table]:
            record_id = str(row.get("id", ""))
            workspace = str(row.get("workspace", ""))
            payload = row.get("data")
            if workspace not in workspace_ids:
                errors.append(f"{table}:{record_id} references a missing workspace")
            if not isinstance(payload, dict):
                errors.append(f"{table}:{record_id} data is not a JSON object")
                continue
            if payload.get("id") != record_id and table != "zar_allocations":
                errors.append(f"{table}:{record_id} outer and payload ids differ")
            payloads[table][record_id] = payload
            workspaces[table][record_id] = workspace

    people = workspaces["zar_people"]
    deals = workspaces["zar_deals"]
    settlements = workspaces["zar_settlements"]
    coin_types = workspaces["zar_coin_types"]
    cash_entries = workspaces["zar_cash_entries"]

    for record_id, payload in payloads["zar_deals"].items():
        workspace = workspaces["zar_deals"][record_id]
        _reference_error(
            errors,
            source=f"zar_deals:{record_id}.personId",
            reference=payload.get("personId"),
            targets=people,
            workspace=workspace,
        )

    for record_id, payload in payloads["zar_settlements"].items():
        workspace = workspaces["zar_settlements"][record_id]
        _reference_error(
            errors,
            source=f"zar_settlements:{record_id}.personId",
            reference=payload.get("personId"),
            targets=people,
            workspace=workspace,
        )
        _reference_error(
            errors,
            source=f"zar_settlements:{record_id}.dealId",
            reference=payload.get("dealId"),
            targets=deals,
            workspace=workspace,
        )

    for record_id, payload in payloads["zar_allocations"].items():
        workspace = workspaces["zar_allocations"][record_id]
        _reference_error(
            errors,
            source=f"zar_allocations:{record_id}.settlementId",
            reference=payload.get("settlementId"),
            targets=settlements,
            workspace=workspace,
        )
        target_type = payload.get("targetType")
        targets = deals if target_type == "deal" else settlements
        if target_type not in {"deal", "settlement"}:
            errors.append(f"zar_allocations:{record_id}.targetType is invalid")
        else:
            _reference_error(
                errors,
                source=f"zar_allocations:{record_id}.targetId",
                reference=payload.get("targetId"),
                targets=targets,
                workspace=workspace,
            )

    for record_id, payload in payloads["zar_cash_entries"].items():
        workspace = workspaces["zar_cash_entries"][record_id]
        _reference_error(
            errors,
            source=f"zar_cash_entries:{record_id}.dealId",
            reference=payload.get("dealId"),
            targets=deals,
            workspace=workspace,
        )
        _reference_error(
            errors,
            source=f"zar_cash_entries:{record_id}.reversesId",
            reference=payload.get("reversesId"),
            targets=cash_entries,
            workspace=workspace,
        )

    def visit_coin_references(value: Any, source: str, workspace: str) -> None:
        if isinstance(value, dict):
            if "coinTypeId" in value:
                _reference_error(
                    errors,
                    source=f"{source}.coinTypeId",
                    reference=value.get("coinTypeId"),
                    targets=coin_types,
                    workspace=workspace,
                )
            for child in value.values():
                visit_coin_references(child, source, workspace)
        elif isinstance(value, list):
            for child in value:
                visit_coin_references(child, source, workspace)

    for table in DOMAIN_TABLES[1:]:
        for record_id, payload in payloads[table].items():
            visit_coin_references(payload, f"{table}:{record_id}", workspaces[table][record_id])

    return sorted(set(errors))


def _inspect_database(database: Path) -> dict[str, Any]:
    with _connect_read_only(database) as connection:
        quick_check = [row[0] for row in connection.execute("PRAGMA quick_check")]
        integrity_check = [row[0] for row in connection.execute("PRAGMA integrity_check")]
        foreign_key_violations = len(list(connection.execute("PRAGMA foreign_key_check")))
        journal_mode = str(connection.execute("PRAGMA journal_mode").fetchone()[0])
        applied_migrations = [
            str(row[0])
            for row in connection.execute("SELECT file FROM _migrations ORDER BY file")
        ]
        snapshots: dict[str, dict[str, Any]] = {}
        domain_rows: dict[str, list[dict[str, Any]]] = {}
        for table in DOMAIN_TABLES:
            count, digest, rows = _table_snapshot(connection, table)
            snapshots[table] = {"count": count, "content_sha256": digest}
            domain_rows[table] = rows
        domain_errors = _validate_domain(domain_rows)
    return {
        "quick_check": quick_check,
        "integrity_check": integrity_check,
        "foreign_key_violations": foreign_key_violations,
        "journal_mode": journal_mode,
        "applied_migrations": applied_migrations,
        "tables": snapshots,
        "domain_errors": domain_errors,
    }


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind(("127.0.0.1", 0))
        return int(listener.getsockname()[1])


def _run_migrations(
    pocketbase: Path,
    data_dir: Path,
    migrations_dir: Path,
) -> str:
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
            f"PocketBase migrate up failed with exit {result.returncode}: "
            f"{(result.stderr or result.stdout).strip()}"
        )
    return "\n".join(
        line for line in (result.stdout + result.stderr).splitlines() if line.strip()
    )


def _prove_health(
    pocketbase: Path,
    data_dir: Path,
    migrations_dir: Path,
    log_path: Path,
) -> None:
    port = _free_port()
    url = f"http://127.0.0.1:{port}/api/health"
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(
            [
                str(pocketbase),
                "serve",
                f"--http=127.0.0.1:{port}",
                f"--dir={data_dir}",
                f"--migrationsDir={migrations_dir}",
            ],
            cwd=data_dir.parent,
            stdout=log,
            stderr=subprocess.STDOUT,
        )
        try:
            deadline = time.monotonic() + 30
            last_error = "no response"
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    raise RuntimeError(
                        f"restored PocketBase exited before health check (exit {process.returncode})"
                    )
                try:
                    with urllib.request.urlopen(url, timeout=2) as response:
                        body = json.loads(response.read())
                    if response.status == 200 and body.get("code") == 200:
                        return
                    last_error = f"HTTP {response.status}"
                except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
                    last_error = str(error)
                time.sleep(0.2)
            raise TimeoutError(f"restored PocketBase health check timed out: {last_error}")
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=10)


def _migration_manifest(migrations_dir: Path) -> dict[str, str]:
    return {
        path.name: _sha256(path)
        for path in sorted(migrations_dir.glob("*.js"), key=lambda item: item.name)
    }


def _checks_pass(inspection: dict[str, Any]) -> bool:
    return (
        inspection["quick_check"] == ["ok"]
        and inspection["integrity_check"] == ["ok"]
        and inspection["foreign_key_violations"] == 0
        and not inspection["domain_errors"]
    )


def verify(args: argparse.Namespace) -> tuple[int, dict[str, Any]]:
    database = Path(args.database).resolve()
    migrations = Path(args.migrations).resolve()
    pocketbase = Path(args.pocketbase).resolve()
    failures: list[str] = []

    if not database.is_file():
        raise FileNotFoundError(f"database not found: {database}")
    if not migrations.is_dir():
        raise FileNotFoundError(f"migrations directory not found: {migrations}")
    if not pocketbase.is_file():
        raise FileNotFoundError(f"PocketBase binary not found: {pocketbase}")
    if os.name != "nt" and not os.access(pocketbase, os.X_OK):
        raise PermissionError(f"PocketBase binary is not executable: {pocketbase}")

    source_hash_before = _sha256(database)
    if args.expected_database_sha256 and source_hash_before != args.expected_database_sha256:
        failures.append("source database SHA-256 does not match the expected value")
    wal_path = Path(f"{database}-wal")
    if wal_path.exists() and wal_path.stat().st_size > 0:
        failures.append("source has a non-empty WAL sidecar; use a consistent backup instead")

    pre = _inspect_database(database)
    manifest = _migration_manifest(migrations)
    if not _checks_pass(pre):
        failures.append("source database failed integrity or domain checks")

    applied_before = set(pre["applied_migrations"])
    migration_names = set(manifest)
    pending_before = sorted(migration_names - applied_before)
    untracked_applied_before = sorted(
        name for name in applied_before if name.endswith(".js") and name not in migration_names
    )
    if untracked_applied_before:
        failures.append("source database contains applied JavaScript migrations absent from Git")

    post: dict[str, Any] | None = None
    migration_output = ""
    health = "not-run"
    with tempfile.TemporaryDirectory(
        prefix="zar-recovery-verify-",
        ignore_cleanup_errors=True,
    ) as temp:
        root = Path(temp)
        data_dir = root / "pb_data"
        restored_migrations = root / "pb_migrations"
        data_dir.mkdir()
        shutil.copy2(database, data_dir / "data.db")
        shutil.copytree(migrations, restored_migrations)
        try:
            migration_output = _run_migrations(pocketbase, data_dir, restored_migrations)
            _prove_health(
                pocketbase,
                data_dir,
                restored_migrations,
                root / "pocketbase.log",
            )
            health = "pass"
            post = _inspect_database(data_dir / "data.db")
        except Exception as error:  # report a complete failed gate
            failures.append(str(error))

    source_hash_after = _sha256(database)
    if source_hash_after != source_hash_before:
        failures.append("source database changed during verification")

    reconciliation: dict[str, bool] = {}
    if post is not None:
        if not _checks_pass(post):
            failures.append("restored database failed integrity or domain checks")
        for table in DOMAIN_TABLES:
            reconciliation[table] = pre["tables"][table] == post["tables"][table]
        if not all(reconciliation.values()):
            failures.append("restored domain rows differ from the source")
        missing_after = sorted(migration_names - set(post["applied_migrations"]))
        if missing_after:
            failures.append("restored database still has unapplied JavaScript migrations")
    else:
        missing_after = sorted(migration_names)

    report = {
        "schema_version": 1,
        "generated_at_utc": datetime.now(UTC).isoformat(),
        "status": "pass" if not failures else "fail",
        "failures": failures,
        "source": {
            "database_sha256": source_hash_before,
            "hash_unchanged": source_hash_before == source_hash_after,
            "expected_sha256_matched": (
                args.expected_database_sha256 is None
                or source_hash_before == args.expected_database_sha256
            ),
        },
        "migrations": {
            "files": manifest,
            "pending_before_restore": pending_before,
            "untracked_applied_before": untracked_applied_before,
            "missing_after_restore": missing_after,
            "runner_output": migration_output,
        },
        "service_health": health,
        "pre_restore": pre,
        "post_restore": post,
        "record_reconciliation": reconciliation,
    }
    return (0 if not failures else 1), report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pocketbase", required=True, help="PocketBase 0.40.4 binary")
    parser.add_argument("--database", required=True, help="consistent source data.db copy")
    parser.add_argument("--migrations", required=True, help="repository pb_migrations directory")
    parser.add_argument("--expected-database-sha256")
    parser.add_argument("--report", help="optional JSON evidence output path")
    args = parser.parse_args()

    try:
        exit_code, report = verify(args)
    except Exception as error:
        report = {
            "schema_version": 1,
            "generated_at_utc": datetime.now(UTC).isoformat(),
            "status": "fail",
            "failures": [str(error)],
        }
        exit_code = 1

    rendered = json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True)
    if args.report:
        report_path = Path(args.report).resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(f"{rendered}\n", encoding="utf-8")
    print(rendered)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
