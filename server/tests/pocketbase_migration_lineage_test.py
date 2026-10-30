"""Exercise supported PocketBase migration lineages on disposable databases."""

from __future__ import annotations

import argparse
import json
import shutil
import sqlite3
import subprocess
import tempfile
from pathlib import Path


BASE_MIGRATIONS = (
    "1758400000_zar_collections.js",
    "1790899200_cash_journal.js",
)
TEMPLATE_MIGRATIONS = (
    "1793020980_updated_users.js",
    "1793023512_updated_users.js",
)
LOCK_MIGRATION = "1793260800_lock_workspace_deletion.js"
CASH_LOCK_MIGRATION = "1793347200_lock_cash_entry_deletion.js"
ALL_MIGRATIONS = (
    *BASE_MIGRATIONS,
    *TEMPLATE_MIGRATIONS,
    LOCK_MIGRATION,
    CASH_LOCK_MIGRATION,
)


def _copy_migrations(source: Path, target: Path, names: tuple[str, ...]) -> None:
    target.mkdir(parents=True, exist_ok=True)
    for name in names:
        shutil.copy2(source / name, target / name)


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
            f"PocketBase migration failed:\n{result.stdout}{result.stderr}"
        )


def _assert_final_state(data_dir: Path) -> None:
    database = data_dir / "data.db"
    connection = sqlite3.connect(f"file:{database.as_posix()}?mode=ro", uri=True)
    try:
        applied = {
            row[0]
            for row in connection.execute(
                "SELECT file FROM _migrations WHERE file LIKE '%.js'"
            )
        }
        if applied != set(ALL_MIGRATIONS):
            raise AssertionError(
                f"unexpected JavaScript migration set: {sorted(applied)}"
            )
        row = connection.execute(
            "SELECT deleteRule FROM _collections WHERE name = 'zar_workspaces'"
        ).fetchone()
        if row is None or row[0] is not None:
            raise AssertionError("workspace deletion lock is not active")
        row = connection.execute(
            "SELECT updateRule, deleteRule FROM _collections "
            "WHERE name = 'zar_cash_entries'"
        ).fetchone()
        if row is None or row[0] is not None or row[1] is not None:
            raise AssertionError("cash journal immutability rules are not active")
        options_row = connection.execute(
            "SELECT options FROM _collections WHERE name = 'users'"
        ).fetchone()
        if options_row is None:
            raise AssertionError("users auth collection is missing")
        options = json.loads(options_row[0])
        expected_subjects = {
            "resetPasswordTemplate": "بازیابی رمز عبور ZAR+",
            "verificationTemplate": "تأیید ایمیل ZAR+",
            "confirmEmailChangeTemplate": "تغییر ایمیل ZAR+",
        }
        for template, expected in expected_subjects.items():
            actual = options.get(template, {}).get("subject")
            if actual != expected:
                raise AssertionError(f"unexpected {template} subject")
        if connection.execute("PRAGMA quick_check").fetchone()[0] != "ok":
            raise AssertionError("quick_check failed")
        if connection.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            raise AssertionError("integrity_check failed")
    finally:
        connection.close()


def run(pocketbase: Path) -> None:
    if not pocketbase.is_file():
        raise FileNotFoundError(f"PocketBase binary not found: {pocketbase}")
    repository_root = Path(__file__).resolve().parents[2]
    source = repository_root / "server" / "pb_migrations"

    with tempfile.TemporaryDirectory(
        prefix="zar-migration-lineage-",
        ignore_cleanup_errors=True,
    ) as temp:
        root = Path(temp)

        fresh_data = root / "fresh" / "pb_data"
        fresh_migrations = root / "fresh" / "pb_migrations"
        _copy_migrations(source, fresh_migrations, ALL_MIGRATIONS)
        _migrate(pocketbase, fresh_data, fresh_migrations)
        _assert_final_state(fresh_data)
        print("PASS fresh-install lineage")

        developer_data = root / "developer" / "pb_data"
        developer_migrations = root / "developer" / "pb_migrations"
        _copy_migrations(
            source,
            developer_migrations,
            (*BASE_MIGRATIONS, LOCK_MIGRATION, CASH_LOCK_MIGRATION),
        )
        _migrate(pocketbase, developer_data, developer_migrations)
        _copy_migrations(source, developer_migrations, TEMPLATE_MIGRATIONS)
        _migrate(pocketbase, developer_data, developer_migrations)
        _assert_final_state(developer_data)
        print("PASS existing-developer lineage")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pocketbase", required=True)
    args = parser.parse_args()
    run(Path(args.pocketbase).resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
