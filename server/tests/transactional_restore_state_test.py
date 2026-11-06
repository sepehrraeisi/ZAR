#!/usr/bin/env python3
"""Tests for the payload-free transactional restore state helper."""

from __future__ import annotations

import json
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "server" / "scripts" / "transactional_restore_state.py"
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
PAYLOAD_SENTINEL = "PRIVATE-FINANCIAL-PAYLOAD-SENTINEL"
SETTINGS_SENTINEL = "PRIVATE-SETTINGS-SENTINEL"
SCHEMA_SENTINEL = "PRIVATE-SCHEMA-SENTINEL"
RECEIPT_SENTINEL = "PRIVATE-RECEIPT-PAYLOAD-SENTINEL"
ACTOR_SENTINEL = "private-actor-id"


def _settings(*, max_requests: int = 10) -> dict[str, Any]:
    return {
        "meta": {"smtpPassword": SETTINGS_SENTINEL},
        "rateLimits": {
            "enabled": True,
            "excludedIPs": [],
            "rules": [
                {
                    "audience": "@auth",
                    "duration": 60,
                    "label": "/api/example",
                    "maxRequests": max_requests,
                }
            ],
        },
    }


def _collection_row(name: str, index: int) -> tuple[Any, ...]:
    member_rule = '@request.auth.id != "" && members.id ?= @request.auth.id'
    cash_rule = '@request.auth.id != "" && workspace.members.id ?= @request.auth.id'
    create_rule = cash_rule if name == "zar_cash_entries" else member_rule
    update_rule = None if name == "zar_cash_entries" else member_rule
    delete_rule = None if name == "zar_cash_entries" else member_rule
    fields = [
        {
            "help": SCHEMA_SENTINEL if name == "zar_people" else "",
            "name": "id",
            "required": True,
            "type": "text",
        }
    ]
    return (
        f"collection-{index}",
        0,
        "base",
        name,
        json.dumps(fields, separators=(",", ":")),
        "[]",
        member_rule,
        member_rule,
        create_rule,
        update_rule,
        delete_rule,
        "{}",
    )


def _create_data_database(path: Path) -> None:
    with closing(sqlite3.connect(path)) as connection, connection:
        connection.executescript(
            """
            PRAGMA foreign_keys = ON;
            CREATE TABLE _migrations (
              file TEXT PRIMARY KEY,
              applied INTEGER NOT NULL
            );
            CREATE TABLE _params (
              id TEXT PRIMARY KEY,
              value TEXT NOT NULL
            );
            CREATE TABLE _collections (
              id TEXT PRIMARY KEY,
              system INTEGER NOT NULL,
              type TEXT NOT NULL,
              name TEXT NOT NULL UNIQUE,
              fields TEXT NOT NULL,
              indexes TEXT NOT NULL,
              listRule TEXT,
              viewRule TEXT,
              createRule TEXT,
              updateRule TEXT,
              deleteRule TEXT,
              options TEXT NOT NULL
            );
            CREATE TABLE zar_workspaces (
              id TEXT PRIMARY KEY,
              displayName TEXT NOT NULL,
              members TEXT NOT NULL,
              createdAt TEXT NOT NULL
            );
            CREATE TABLE zar_people (
              id TEXT PRIMARY KEY,
              workspace TEXT NOT NULL,
              data TEXT NOT NULL,
              created TEXT NOT NULL
            );
            CREATE TABLE zar_deals (
              id TEXT PRIMARY KEY,
              workspace TEXT NOT NULL,
              data TEXT NOT NULL,
              created TEXT NOT NULL
            );
            CREATE TABLE zar_settlements (
              id TEXT PRIMARY KEY,
              workspace TEXT NOT NULL,
              data TEXT NOT NULL,
              created TEXT NOT NULL
            );
            CREATE TABLE zar_coin_types (
              id TEXT PRIMARY KEY,
              workspace TEXT NOT NULL,
              data TEXT NOT NULL,
              created TEXT NOT NULL
            );
            CREATE TABLE zar_currency_types (
              id TEXT PRIMARY KEY,
              workspace TEXT NOT NULL,
              data TEXT NOT NULL,
              created TEXT NOT NULL
            );
            CREATE TABLE zar_allocations (
              id TEXT PRIMARY KEY,
              workspace TEXT NOT NULL,
              data TEXT NOT NULL,
              created TEXT NOT NULL
            );
            CREATE TABLE zar_cash_entries (
              id TEXT PRIMARY KEY,
              workspace TEXT NOT NULL,
              data TEXT NOT NULL,
              created TEXT NOT NULL
            );
            """
        )
        connection.executemany(
            "INSERT INTO _migrations(file, applied) VALUES (?, ?)",
            [
                ("100_first.js", 100),
                ("200_second.js", 200),
            ],
        )
        connection.execute(
            "INSERT INTO _params(id, value) VALUES ('settings', ?)",
            (json.dumps(_settings(), separators=(",", ":")),),
        )
        connection.executemany(
            """
            INSERT INTO _collections(
              id, system, type, name, fields, indexes,
              listRule, viewRule, createRule, updateRule, deleteRule, options
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [_collection_row(name, index) for index, name in enumerate(DOMAIN_TABLES)],
        )
        connection.execute(
            """
            INSERT INTO zar_workspaces(id, displayName, members, createdAt)
            VALUES ('workspace-1', 'Private business', '["user-1"]', '2026-01-01')
            """
        )
        for table in DOMAIN_TABLES[1:]:
            payload = {
                "amount": 1,
                "private": PAYLOAD_SENTINEL,
                "table": table,
            }
            connection.execute(
                f"""
                INSERT INTO {table}(id, workspace, data, created)
                VALUES (?, 'workspace-1', ?, '2026-01-01')
                """,
                (f"{table}-1", json.dumps(payload, separators=(",", ":"))),
            )


def _create_auxiliary_database(path: Path) -> None:
    with closing(sqlite3.connect(path)) as connection, connection:
        connection.execute(
            "CREATE TABLE _logs (id TEXT PRIMARY KEY, message TEXT NOT NULL)"
        )
        connection.execute("INSERT INTO _logs VALUES ('log-1', 'private log')")


def _add_receipt_schema(path: Path) -> None:
    with closing(sqlite3.connect(path)) as connection, connection:
        connection.execute(
            """
            CREATE TABLE zar_restore_receipts (
              id TEXT PRIMARY KEY,
              workspace TEXT NOT NULL,
              actor TEXT NOT NULL,
              protocolVersion INTEGER NOT NULL,
              snapshotHash TEXT NOT NULL,
              beforeHash TEXT NOT NULL,
              afterHash TEXT NOT NULL,
              counts TEXT NOT NULL,
              committedAt TEXT NOT NULL,
              payload TEXT
            )
            """
        )
        receipt_rules = (None, None, None, None, None)
        connection.execute(
            """
            INSERT INTO _collections(
              id, system, type, name, fields, indexes,
              listRule, viewRule, createRule, updateRule, deleteRule, options
            ) VALUES (?, 0, 'base', 'zar_restore_receipts', ?, '[]', ?, ?, ?, ?, ?, '{}')
            """,
            (
                "collection-receipts",
                json.dumps([{"name": "id", "type": "text"}]),
                *receipt_rules,
            ),
        )
        counts = {
            "cashEntries": 0,
            "coinTypes": 0,
            "currencyTypes": 0,
            "deals": 0,
            "paymentAllocations": 0,
            "people": 1,
            "settlements": 0,
            "total": 1,
        }
        connection.execute(
            """
            INSERT INTO zar_restore_receipts(
              id, workspace, actor, protocolVersion, snapshotHash,
              beforeHash, afterHash, counts, committedAt, payload
            ) VALUES (?, ?, ?, 1, ?, ?, ?, ?, ?, ?)
            """,
            (
                "a" * 32,
                "workspace-1",
                ACTOR_SENTINEL,
                "1" * 64,
                "2" * 64,
                "3" * 64,
                json.dumps(counts, separators=(",", ":")),
                "2026-01-01T00:00:00Z",
                RECEIPT_SENTINEL,
            ),
        )


class TransactionalRestoreStateTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="zar-state-test-")
        self.root = Path(self.temporary.name)
        self.database = self.root / "data.db"
        self.auxiliary = self.root / "auxiliary.db"
        _create_data_database(self.database)
        _create_auxiliary_database(self.auxiliary)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def run_helper(
        self,
        *,
        database: Path | str | None = None,
        auxiliary: Path | str | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(HELPER),
                "--database",
                str(database if database is not None else self.database),
                "--auxiliary",
                str(auxiliary if auxiliary is not None else self.auxiliary),
            ],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

    def state(self) -> tuple[str, dict[str, Any]]:
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout, json.loads(result.stdout)

    def test_output_is_deterministic_sanitized_and_complete(self) -> None:
        first_raw, first = self.state()
        second_raw, second = self.state()

        self.assertEqual(first_raw, second_raw)
        self.assertEqual(first, second)
        for sentinel in (
            PAYLOAD_SENTINEL,
            SETTINGS_SENTINEL,
            SCHEMA_SENTINEL,
            RECEIPT_SENTINEL,
            ACTOR_SENTINEL,
            "Private business",
        ):
            self.assertNotIn(sentinel, first_raw)

        self.assertEqual(first["schemaVersion"], 1)
        self.assertEqual(first["databases"]["data"]["quickCheck"], ["ok"])
        self.assertEqual(first["databases"]["auxiliary"]["integrityCheck"], ["ok"])
        self.assertEqual(first["databases"]["data"]["foreignKeyViolations"], 0)
        self.assertEqual(first["migrations"]["ordered"], ["100_first.js", "200_second.js"])
        self.assertEqual(first["migrations"]["latest"], "200_second.js")
        self.assertEqual(first["settings"]["rateLimits"]["count"], 1)
        self.assertEqual(set(first["domainTables"]), set(DOMAIN_TABLES))
        self.assertEqual(first["domainTables"]["zar_people"]["count"], 1)
        self.assertFalse(first["restoreReceipts"]["present"])
        self.assertIsNone(first["restoreReceipts"]["metadataSha256"])
        self.assertTrue(first["collections"]["rules"]["zar_workspaces"]["present"])
        self.assertFalse(
            first["collections"]["rules"]["zar_restore_receipts"]["present"]
        )

    def test_json_formatting_is_canonical_but_real_mutations_change_hashes(self) -> None:
        _, before = self.state()
        with closing(sqlite3.connect(self.database)) as connection, connection:
            connection.execute(
                "UPDATE zar_people SET data=? WHERE id='zar_people-1'",
                (
                    '{ "table" : "zar_people", "private" : '
                    f'"{PAYLOAD_SENTINEL}", "amount" : 1 }}',
                ),
            )
            fields = [
                {
                    "type": "text",
                    "required": True,
                    "name": "id",
                    "help": SCHEMA_SENTINEL,
                }
            ]
            connection.execute(
                "UPDATE _collections SET fields=? WHERE name='zar_people'",
                (json.dumps(fields, indent=2),),
            )
            connection.execute(
                "UPDATE _params SET value=? WHERE id='settings'",
                (json.dumps(_settings(), indent=2, sort_keys=True),),
            )
        _, reformatted = self.state()
        self.assertEqual(
            before["domainTables"]["zar_people"]["contentSha256"],
            reformatted["domainTables"]["zar_people"]["contentSha256"],
        )
        self.assertEqual(
            before["collections"]["fingerprints"]["zar_people"],
            reformatted["collections"]["fingerprints"]["zar_people"],
        )
        self.assertEqual(before["settings"], reformatted["settings"])

        with closing(sqlite3.connect(self.database)) as connection, connection:
            changed_payload = {
                "amount": 2,
                "private": PAYLOAD_SENTINEL,
                "table": "zar_people",
            }
            connection.execute(
                "UPDATE zar_people SET data=? WHERE id='zar_people-1'",
                (json.dumps(changed_payload),),
            )
            connection.execute(
                "INSERT INTO _migrations(file, applied) VALUES ('300_third.js', 300)"
            )
            connection.execute(
                "UPDATE _params SET value=? WHERE id='settings'",
                (json.dumps(_settings(max_requests=11)),),
            )
            changed_fields = [
                {
                    "help": SCHEMA_SENTINEL,
                    "name": "id",
                    "required": False,
                    "type": "text",
                }
            ]
            connection.execute(
                "UPDATE _collections SET fields=? WHERE name='zar_people'",
                (json.dumps(changed_fields),),
            )
        _, changed = self.state()
        self.assertNotEqual(
            reformatted["domainTables"]["zar_people"]["contentSha256"],
            changed["domainTables"]["zar_people"]["contentSha256"],
        )
        self.assertNotEqual(reformatted["migrations"]["sha256"], changed["migrations"]["sha256"])
        self.assertEqual(changed["migrations"]["latest"], "300_third.js")
        self.assertNotEqual(reformatted["settings"]["sha256"], changed["settings"]["sha256"])
        self.assertNotEqual(
            reformatted["settings"]["rateLimits"]["sha256"],
            changed["settings"]["rateLimits"]["sha256"],
        )
        self.assertNotEqual(
            reformatted["collections"]["fingerprints"]["zar_people"],
            changed["collections"]["fingerprints"]["zar_people"],
        )

    def test_receipt_metadata_hash_excludes_payload_and_canonicalizes_counts(self) -> None:
        _, absent = self.state()
        self.assertEqual(
            absent["restoreReceipts"],
            {"count": 0, "metadataSha256": None, "present": False},
        )

        _add_receipt_schema(self.database)
        raw, present = self.state()
        self.assertNotIn(RECEIPT_SENTINEL, raw)
        self.assertNotIn(ACTOR_SENTINEL, raw)
        receipts = present["restoreReceipts"]
        self.assertTrue(receipts["present"])
        self.assertEqual(receipts["count"], 1)
        original_hash = receipts["metadataSha256"]
        self.assertIsInstance(original_hash, str)

        with closing(sqlite3.connect(self.database)) as connection, connection:
            counts = json.loads(
                connection.execute(
                    "SELECT counts FROM zar_restore_receipts"
                ).fetchone()[0]
            )
            connection.execute(
                "UPDATE zar_restore_receipts SET payload=?, counts=?",
                ("changed private payload", json.dumps(counts, indent=2, sort_keys=True)),
            )
        raw, payload_changed = self.state()
        self.assertNotIn("changed private payload", raw)
        self.assertEqual(
            original_hash,
            payload_changed["restoreReceipts"]["metadataSha256"],
        )

        with closing(sqlite3.connect(self.database)) as connection, connection:
            connection.execute(
                "UPDATE zar_restore_receipts SET snapshotHash=?",
                ("c" * 64,),
            )
        _, metadata_changed = self.state()
        self.assertNotEqual(
            original_hash,
            metadata_changed["restoreReceipts"]["metadataSha256"],
        )

    def test_missing_relative_and_invalid_databases_fail_without_json(self) -> None:
        missing = self.root / "missing.db"
        missing_result = self.run_helper(database=missing)
        self.assertNotEqual(missing_result.returncode, 0)
        self.assertEqual(missing_result.stdout, "")

        invalid = self.root / "invalid.db"
        invalid.write_text("not sqlite", encoding="utf-8")
        invalid_result = self.run_helper(database=invalid)
        self.assertNotEqual(invalid_result.returncode, 0)
        self.assertEqual(invalid_result.stdout, "")

        empty = self.root / "empty.db"
        empty.touch()
        empty_result = self.run_helper(auxiliary=empty)
        self.assertNotEqual(empty_result.returncode, 0)
        self.assertEqual(empty_result.stdout, "")

        relative_result = self.run_helper(database="relative.db")
        self.assertNotEqual(relative_result.returncode, 0)
        self.assertEqual(relative_result.stdout, "")


if __name__ == "__main__":
    unittest.main(verbosity=2)
