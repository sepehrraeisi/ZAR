#!/usr/bin/env python3
"""Validate sanitized transactional-restore deployment states fail closed."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


class GuardError(RuntimeError):
    pass


def _read_json(path_value: str, label: str) -> dict[str, Any]:
    path = Path(path_value)
    if not path.is_absolute() or path.is_symlink() or not path.is_file():
        raise GuardError(f"{label} must be an absolute regular non-symlink file")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise GuardError(f"{label} is not valid UTF-8 JSON") from error
    if not isinstance(value, dict):
        raise GuardError(f"{label} root must be an object")
    return value


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise GuardError(message)


def _healthy_database(value: Any) -> bool:
    return (
        isinstance(value, dict)
        and value.get("quickCheck") == ["ok"]
        and value.get("integrityCheck") == ["ok"]
        and value.get("foreignKeyViolations") == 0
    )


def _rules(state: dict[str, Any], collection: str) -> dict[str, Any] | None:
    collections = state.get("collections")
    if not isinstance(collections, dict):
        raise GuardError("state collections are missing")
    explicit = collections.get("rules")
    if not isinstance(explicit, dict):
        raise GuardError("state collection rules are missing")
    entry = explicit.get(collection)
    if not isinstance(entry, dict) or not isinstance(entry.get("present"), bool):
        raise GuardError(f"state rule entry is missing for {collection}")
    rules = entry.get("rules")
    if entry["present"]:
        if not isinstance(rules, dict):
            raise GuardError(f"state rules are missing for {collection}")
        return rules
    _require(rules is None, f"absent {collection} unexpectedly has rules")
    return None


def _validate_common(state: dict[str, Any]) -> None:
    _require(state.get("schemaVersion") == 1, "unsupported state schema")
    databases = state.get("databases")
    _require(isinstance(databases, dict), "database checks are missing")
    _require(_healthy_database(databases.get("data")), "data database checks failed")
    _require(
        _healthy_database(databases.get("auxiliary")),
        "auxiliary database checks failed",
    )

    cash_rules = _rules(state, "zar_cash_entries")
    _require(cash_rules is not None, "cash collection is missing")
    _require(cash_rules.get("updateRule") is None, "cash update lock drifted")
    _require(cash_rules.get("deleteRule") is None, "cash delete lock drifted")

    domain = state.get("domainTables")
    _require(isinstance(domain, dict) and len(domain) == 8, "domain table state is incomplete")
    for name, value in domain.items():
        _require(isinstance(name, str) and isinstance(value, dict), "invalid domain state")
        _require(isinstance(value.get("count"), int), f"invalid count for {name}")
        digest = value.get("contentSha256")
        _require(isinstance(digest, str) and len(digest) == 64, f"invalid hash for {name}")


def _validate_profile(
    state: dict[str, Any],
    expected: dict[str, Any],
    profile: str,
    expected_receipt_count: int | None,
) -> None:
    _validate_common(state)
    artifacts = expected.get("artifacts")
    baseline = expected.get("productionBaseline")
    _require(isinstance(artifacts, dict) and isinstance(baseline, dict), "expected manifest is incomplete")
    migration = artifacts.get("migration")
    _require(isinstance(migration, dict), "expected migration is missing")
    migration_name = migration.get("name")
    baseline_latest = baseline.get("latestMigration")
    _require(isinstance(migration_name, str), "expected migration name is invalid")
    _require(isinstance(baseline_latest, str), "baseline latest migration is invalid")

    migrations = state.get("migrations")
    _require(isinstance(migrations, dict), "migration state is missing")
    ordered = migrations.get("ordered")
    _require(isinstance(ordered, list) and all(isinstance(v, str) for v in ordered), "ordered migration state is invalid")
    candidate_present = migration_name in ordered

    settings = state.get("settings")
    _require(isinstance(settings, dict), "settings state is missing")
    expected_non_rate_settings = baseline.get("nonRateLimitSettingsSha256")
    _require(
        isinstance(expected_non_rate_settings, str)
        and len(expected_non_rate_settings) == 64,
        "expected non-rate-limit settings hash is missing",
    )
    _require(
        settings.get("nonRateLimitSettingsSha256") == expected_non_rate_settings,
        "non-rate-limit settings drifted",
    )
    rate_limits = settings.get("rateLimits")
    _require(isinstance(rate_limits, dict), "rate-limit state is missing")
    actual_policy = {
        "enabled": rate_limits.get("enabled"),
        "excludedIPs": rate_limits.get("excludedIPs"),
        "rules": rate_limits.get("rules"),
    }

    workspace_rules = _rules(state, "zar_workspaces")
    _require(workspace_rules is not None, "workspace collection is missing")
    receipts = state.get("restoreReceipts")
    _require(isinstance(receipts, dict), "receipt state is missing")
    receipt_rules = _rules(state, "zar_restore_receipts")

    if profile == "before":
        expected_policy = expected.get("rateLimitsBefore")
        expected_workspace_rule = expected.get("workspaceUpdateRuleBefore")
        _require(not candidate_present, "candidate migration already applied")
        _require(migrations.get("latest") == baseline_latest, "baseline latest migration drifted")
        _require(receipt_rules is None, "receipt collection exists before deployment")
        _require(receipts.get("present") is False and receipts.get("count") == 0, "receipt state exists before deployment")
    elif profile in {"after", "contained"}:
        expected_policy = expected.get("rateLimitsAfter")
        expected_workspace_rule = expected.get("workspaceUpdateRuleLocked")
        _require(candidate_present, "candidate migration is not applied")
        _require(migrations.get("latest") == migration_name, "candidate is not latest migration")
        _require(receipt_rules is not None, "receipt collection is missing")
        _require(all(receipt_rules.get(key) is None for key in ("listRule", "viewRule", "createRule", "updateRule", "deleteRule")), "receipt Record API is not private")
        _require(receipts.get("present") is True, "receipt metadata state is missing")
    elif profile == "rolled-back":
        expected_policy = expected.get("rateLimitsBefore")
        expected_workspace_rule = expected.get("workspaceUpdateRuleLocked")
        _require(not candidate_present, "candidate migration remains after rollback")
        _require(migrations.get("latest") == baseline_latest, "rollback latest migration drifted")
        _require(receipt_rules is None, "receipt collection remains after rollback")
        _require(receipts.get("present") is False and receipts.get("count") == 0, "receipt state remains after rollback")
    else:
        raise GuardError(f"unsupported profile: {profile}")

    _require(actual_policy == expected_policy, f"{profile} rate policy drifted")
    _require(rate_limits.get("count") == len(expected_policy["rules"]), "rate rule count drifted")
    _require(workspace_rules.get("updateRule") == expected_workspace_rule, "workspace membership rule drifted")
    if expected_receipt_count is not None:
        _require(receipts.get("count") == expected_receipt_count, "receipt count drifted")


def _compare_to_baseline(
    state: dict[str, Any], baseline: dict[str, Any], profile: str
) -> None:
    _require(state.get("domainTables") == baseline.get("domainTables"), "domain table hashes/counts changed")
    _require(
        state.get("settings", {}).get("nonRateLimitSettingsSha256")
        == baseline.get("settings", {}).get("nonRateLimitSettingsSha256"),
        "non-rate-limit settings changed from baseline",
    )
    state_migrations = state.get("migrations", {}).get("ordered")
    baseline_migrations = baseline.get("migrations", {}).get("ordered")
    _require(isinstance(state_migrations, list) and isinstance(baseline_migrations, list), "migration lists are missing")
    if profile in {"after", "contained"}:
        _require(len(state_migrations) == len(baseline_migrations) + 1, "migration history delta is not exactly one")
        _require(state_migrations[:-1] == baseline_migrations, "baseline migration history changed")
    else:
        _require(state_migrations == baseline_migrations, "baseline migration history was not restored")

    baseline_fingerprints = baseline.get("collections", {}).get("fingerprints")
    state_fingerprints = state.get("collections", {}).get("fingerprints")
    baseline_structural = baseline.get("collections", {}).get("structuralFingerprints")
    state_structural = state.get("collections", {}).get("structuralFingerprints")
    _require(isinstance(baseline_fingerprints, dict) and isinstance(state_fingerprints, dict), "collection fingerprints are missing")
    _require(isinstance(baseline_structural, dict) and isinstance(state_structural, dict), "collection structural fingerprints are missing")
    baseline_names = set(baseline_fingerprints)
    state_names = set(state_fingerprints)
    expected_names = baseline_names | {"zar_restore_receipts"} if profile in {"after", "contained"} else baseline_names
    _require(state_names == expected_names, "collection name set changed unexpectedly")
    _require(set(baseline_structural) == baseline_names, "baseline structural collection set is inconsistent")
    _require(set(state_structural) == state_names, "state structural collection set is inconsistent")

    allowed = {"zar_workspaces"}
    for name, digest in baseline_fingerprints.items():
        if name in allowed:
            continue
        _require(state_fingerprints.get(name) == digest, f"collection schema changed unexpectedly: {name}")
    _require(
        state_structural.get("zar_workspaces") == baseline_structural.get("zar_workspaces"),
        "workspace collection structure changed unexpectedly",
    )
    baseline_workspace_rules = _rules(baseline, "zar_workspaces")
    state_workspace_rules = _rules(state, "zar_workspaces")
    _require(
        baseline_workspace_rules is not None and state_workspace_rules is not None,
        "workspace rules are missing",
    )
    for key in ("listRule", "viewRule", "createRule", "deleteRule"):
        _require(
            state_workspace_rules.get(key) == baseline_workspace_rules.get(key),
            f"workspace {key} changed unexpectedly",
        )


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", required=True)
    parser.add_argument("--expected", required=True)
    parser.add_argument("--profile", required=True, choices=("before", "after", "rolled-back", "contained"))
    parser.add_argument("--baseline")
    parser.add_argument("--expected-receipt-count", type=int)
    return parser.parse_args()


def main() -> int:
    try:
        args = _parse_args()
        state = _read_json(args.state, "state")
        expected = _read_json(args.expected, "expected manifest")
        _require(expected.get("schemaVersion") == 1, "unsupported expected manifest schema")
        _validate_profile(state, expected, args.profile, args.expected_receipt_count)
        if args.baseline:
            baseline = _read_json(args.baseline, "baseline state")
            _validate_profile(baseline, expected, "before", 0)
            _compare_to_baseline(state, baseline, args.profile)
        elif args.profile not in {"before", "contained"}:
            raise GuardError("a baseline state is required for this profile")
        print(f"TRANSACTIONAL_RESTORE_STATE_GUARD_PASS profile={args.profile}")
        return 0
    except (GuardError, OSError, KeyError, TypeError, ValueError) as error:
        print(f"transactional restore state guard failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
