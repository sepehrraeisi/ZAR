#!/usr/bin/env python3
"""Emit a deterministic, payload-free PocketBase deployment state snapshot.

The helper is intentionally read-only.  It is designed for guarded migration,
rollback, and clone-rehearsal scripts that need exact comparisons without
placing financial rows, user identifiers, or receipt metadata in evidence.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import sys
from contextlib import closing
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import quote


SCHEMA_VERSION = 1
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
    "zar_workspaces": frozenset({"members"}),
    "zar_people": frozenset({"data"}),
    "zar_deals": frozenset({"data"}),
    "zar_settlements": frozenset({"data"}),
    "zar_coin_types": frozenset({"data"}),
    "zar_currency_types": frozenset({"data"}),
    "zar_allocations": frozenset({"data"}),
    "zar_cash_entries": frozenset({"data"}),
}
EXPLICIT_RULE_COLLECTIONS = (
    "zar_workspaces",
    "zar_cash_entries",
    "zar_restore_receipts",
)
RULE_COLUMNS = (
    "listRule",
    "viewRule",
    "createRule",
    "updateRule",
    "deleteRule",
)
RECEIPT_COLUMNS = (
    "id",
    "workspace",
    "actor",
    "protocolVersion",
    "snapshotHash",
    "beforeHash",
    "afterHash",
    "counts",
    "committedAt",
)


def _canonical_json(value: Any) -> str:
    return json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    )


def _digest(value: Any) -> str:
    return hashlib.sha256(_canonical_json(value).encode("utf-8")).hexdigest()


def _reject_duplicate_keys(pairs: Iterable[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"JSON contains a duplicate key: {key}")
        result[key] = value
    return result


def _parse_json(value: Any, label: str) -> Any:
    if isinstance(value, bytes):
        try:
            value = value.decode("utf-8")
        except UnicodeDecodeError as error:
            raise ValueError(f"{label} is not UTF-8 JSON") from error
    if not isinstance(value, str):
        raise ValueError(f"{label} is not stored as JSON text")
    try:
        return json.loads(value, object_pairs_hook=_reject_duplicate_keys)
    except (TypeError, json.JSONDecodeError) as error:
        raise ValueError(f"{label} contains invalid JSON") from error


def _scalar(value: Any) -> Any:
    if isinstance(value, bytes):
        return {"bytesSha256": hashlib.sha256(value).hexdigest()}
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    raise ValueError(f"unsupported SQLite value type: {type(value).__name__}")


def _validated_database_path(value: str, label: str) -> Path:
    path = Path(value)
    if not path.is_absolute():
        raise ValueError(f"{label} path must be absolute")
    if path.is_symlink():
        raise ValueError(f"{label} path must not be a symlink")
    if not path.is_file():
        raise ValueError(f"{label} database is missing or not a regular file")
    with path.open("rb") as source:
        if source.read(16) != b"SQLite format 3\x00":
            raise ValueError(f"{label} file is not a SQLite 3 database")
    wal = Path(f"{path}-wal")
    if wal.exists() and wal.stat().st_size > 0:
        raise ValueError(f"{label} database has a non-empty WAL sidecar")
    return path.resolve(strict=True)


def _connect_read_only(path: Path) -> sqlite3.Connection:
    encoded = quote(path.as_posix(), safe="/:")
    connection = sqlite3.connect(
        f"file:{encoded}?mode=ro&immutable=1",
        uri=True,
    )
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA query_only = ON")
    return connection


def _database_health(connection: sqlite3.Connection, label: str) -> dict[str, Any]:
    quick = [str(row[0]) for row in connection.execute("PRAGMA quick_check")]
    integrity = [str(row[0]) for row in connection.execute("PRAGMA integrity_check")]
    foreign_keys = len(list(connection.execute("PRAGMA foreign_key_check")))
    if quick != ["ok"]:
        raise ValueError(f"{label} quick_check failed")
    if integrity != ["ok"]:
        raise ValueError(f"{label} integrity_check failed")
    if foreign_keys != 0:
        raise ValueError(f"{label} has foreign-key violations")
    return {
        "foreignKeyViolations": foreign_keys,
        "integrityCheck": integrity,
        "quickCheck": quick,
    }


def _require_table(connection: sqlite3.Connection, table: str) -> None:
    row = connection.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
        (table,),
    ).fetchone()
    if row is None:
        raise ValueError(f"required table is missing: {table}")


def _migration_snapshot(connection: sqlite3.Connection) -> dict[str, Any]:
    _require_table(connection, "_migrations")
    columns = {
        str(row["name"])
        for row in connection.execute('PRAGMA table_info("_migrations")')
    }
    if not {"file", "applied"}.issubset(columns):
        raise ValueError("_migrations schema is invalid")
    ordered = [
        str(row["file"])
        for row in connection.execute(
            'SELECT file FROM "_migrations" ORDER BY applied, file'
        )
    ]
    return {
        "count": len(ordered),
        "latest": ordered[-1] if ordered else None,
        "ordered": ordered,
        "sha256": _digest(ordered),
    }


def _settings_snapshot(connection: sqlite3.Connection) -> dict[str, Any]:
    _require_table(connection, "_params")
    row = connection.execute(
        'SELECT value FROM "_params" WHERE id=?',
        ("settings",),
    ).fetchone()
    if row is None:
        raise ValueError("PocketBase settings row is missing")
    settings = _parse_json(row["value"], "PocketBase settings")
    if not isinstance(settings, dict):
        raise ValueError("PocketBase settings must be a JSON object")
    rate_limits = settings.get("rateLimits")
    if not isinstance(rate_limits, dict):
        raise ValueError("PocketBase rateLimits settings are missing or invalid")
    enabled = rate_limits.get("enabled")
    excluded_ips = rate_limits.get("excludedIPs")
    rules = rate_limits.get("rules")
    if not isinstance(enabled, bool):
        raise ValueError("rateLimits.enabled must be boolean")
    if not isinstance(excluded_ips, list):
        raise ValueError("rateLimits.excludedIPs must be an array")
    if not isinstance(rules, list) or any(not isinstance(rule, dict) for rule in rules):
        raise ValueError("rateLimits.rules must be an array of objects")
    canonical_rate_limits = {
        "enabled": enabled,
        "excludedIPs": excluded_ips,
        "rules": rules,
    }
    non_rate_limit_settings = dict(settings)
    non_rate_limit_settings.pop("rateLimits", None)
    return {
        "rateLimits": {
            **canonical_rate_limits,
            "count": len(rules),
            "sha256": _digest(canonical_rate_limits),
        },
        "nonRateLimitSettingsSha256": _digest(non_rate_limit_settings),
        "sha256": _digest(settings),
    }


def _collection_snapshot(connection: sqlite3.Connection) -> dict[str, Any]:
    _require_table(connection, "_collections")
    required = {
        "id",
        "system",
        "type",
        "name",
        "fields",
        "indexes",
        "options",
        *RULE_COLUMNS,
    }
    columns = {
        str(row["name"])
        for row in connection.execute('PRAGMA table_info("_collections")')
    }
    missing = sorted(required - columns)
    if missing:
        raise ValueError(f"_collections is missing required columns: {', '.join(missing)}")

    fingerprints: dict[str, str] = {}
    structural_fingerprints: dict[str, str] = {}
    rules_by_name: dict[str, dict[str, Any]] = {}
    select_columns = [
        "id",
        "system",
        "type",
        "name",
        "fields",
        "indexes",
        "options",
        *RULE_COLUMNS,
    ]
    quoted = ", ".join(f'"{column}"' for column in select_columns)
    for row in connection.execute(
        f'SELECT {quoted} FROM "_collections" ORDER BY name, id'
    ):
        name = str(row["name"])
        if name in fingerprints:
            raise ValueError(f"duplicate collection name: {name}")
        structural = {
            "fields": _parse_json(row["fields"], f"{name}.fields"),
            "id": str(row["id"]),
            "indexes": _parse_json(row["indexes"], f"{name}.indexes"),
            "name": name,
            "options": _parse_json(row["options"], f"{name}.options"),
            "system": bool(row["system"]),
            "type": str(row["type"]),
        }
        rules = {column: _scalar(row[column]) for column in RULE_COLUMNS}
        structure = {**structural, "rules": rules}
        fingerprints[name] = _digest(structure)
        structural_fingerprints[name] = _digest(structural)
        rules_by_name[name] = rules

    for required_domain in DOMAIN_TABLES:
        if required_domain not in fingerprints:
            raise ValueError(f"domain collection is missing: {required_domain}")

    explicit_rules: dict[str, Any] = {}
    for name in EXPLICIT_RULE_COLLECTIONS:
        explicit_rules[name] = {
            "present": name in fingerprints,
            "rules": rules_by_name.get(name),
        }
    return {
        "fingerprints": fingerprints,
        "structuralFingerprints": structural_fingerprints,
        "rules": explicit_rules,
    }


def _domain_snapshot(connection: sqlite3.Connection) -> dict[str, Any]:
    snapshots: dict[str, Any] = {}
    for table in DOMAIN_TABLES:
        _require_table(connection, table)
        columns = [
            str(row["name"])
            for row in connection.execute(f'PRAGMA table_info("{table}")')
        ]
        if "id" not in columns:
            raise ValueError(f"{table} is missing its id column")
        rows: list[dict[str, Any]] = []
        for source in connection.execute(
            f'SELECT * FROM "{table}" ORDER BY "id" COLLATE BINARY'
        ):
            normalized: dict[str, Any] = {}
            for column in columns:
                value = source[column]
                if column in JSON_COLUMNS[table] and value is not None:
                    value = _parse_json(value, f"{table}.{column}")
                else:
                    value = _scalar(value)
                normalized[column] = value
            rows.append(normalized)
        snapshots[table] = {
            "contentSha256": _digest(rows),
            "count": len(rows),
        }
    return snapshots


def _receipt_snapshot(connection: sqlite3.Connection) -> dict[str, Any]:
    exists = connection.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
        ("zar_restore_receipts",),
    ).fetchone()
    if exists is None:
        return {"count": 0, "metadataSha256": None, "present": False}

    columns = {
        str(row["name"])
        for row in connection.execute('PRAGMA table_info("zar_restore_receipts")')
    }
    missing = sorted(set(RECEIPT_COLUMNS) - columns)
    if missing:
        raise ValueError(
            "zar_restore_receipts is missing required metadata columns: "
            + ", ".join(missing)
        )
    quoted = ", ".join(f'"{column}"' for column in RECEIPT_COLUMNS)
    metadata: list[dict[str, Any]] = []
    for source in connection.execute(
        f'SELECT {quoted} FROM "zar_restore_receipts" '
        'ORDER BY "id" COLLATE BINARY'
    ):
        row: dict[str, Any] = {}
        for column in RECEIPT_COLUMNS:
            value = source[column]
            if column == "counts":
                value = _parse_json(value, "zar_restore_receipts.counts")
            else:
                value = _scalar(value)
            row[column] = value
        metadata.append(row)
    return {
        "count": len(metadata),
        "metadataSha256": _digest(metadata),
        "present": True,
    }


def build_state(database: Path, auxiliary: Path) -> dict[str, Any]:
    with closing(_connect_read_only(database)) as data_connection:
        data_health = _database_health(data_connection, "data")
        migrations = _migration_snapshot(data_connection)
        settings = _settings_snapshot(data_connection)
        collections = _collection_snapshot(data_connection)
        domain_tables = _domain_snapshot(data_connection)
        receipts = _receipt_snapshot(data_connection)
    with closing(_connect_read_only(auxiliary)) as auxiliary_connection:
        auxiliary_health = _database_health(auxiliary_connection, "auxiliary")
    return {
        "collections": collections,
        "databases": {
            "auxiliary": auxiliary_health,
            "data": data_health,
        },
        "domainTables": domain_tables,
        "migrations": migrations,
        "restoreReceipts": receipts,
        "schemaVersion": SCHEMA_VERSION,
        "settings": settings,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", required=True, help="absolute data.db path")
    parser.add_argument(
        "--auxiliary",
        required=True,
        help="absolute auxiliary.db path",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    arguments = _parser().parse_args(argv)
    try:
        database = _validated_database_path(arguments.database, "data")
        auxiliary = _validated_database_path(arguments.auxiliary, "auxiliary")
        state = build_state(database, auxiliary)
    except (OSError, ValueError, sqlite3.Error) as error:
        print(f"transactional_restore_state: {error}", file=sys.stderr)
        return 1
    print(_canonical_json(state))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
