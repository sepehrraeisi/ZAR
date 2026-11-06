from __future__ import annotations

import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GUARD = ROOT / "server" / "scripts" / "transactional_restore_state_guard.py"
EXPECTED = ROOT / "server" / "scripts" / "transactional_restore_expected_state.json"
TABLES = (
    "zar_workspaces",
    "zar_people",
    "zar_deals",
    "zar_settlements",
    "zar_coin_types",
    "zar_currency_types",
    "zar_allocations",
    "zar_cash_entries",
)
RULE_KEYS = ("listRule", "viewRule", "createRule", "updateRule", "deleteRule")


def _rules(update: str | None = None, delete: str | None = None) -> dict[str, object]:
    return {
        "listRule": "@request.auth.id != ''",
        "viewRule": "@request.auth.id != ''",
        "createRule": "@request.auth.id != ''",
        "updateRule": update,
        "deleteRule": delete,
    }


class TransactionalRestoreStateGuardTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.expected = json.loads(EXPECTED.read_text(encoding="utf-8"))

    def _baseline(self) -> dict[str, object]:
        latest = self.expected["productionBaseline"]["latestMigration"]
        return {
            "schemaVersion": 1,
            "databases": {
                "data": {"quickCheck": ["ok"], "integrityCheck": ["ok"], "foreignKeyViolations": 0},
                "auxiliary": {"quickCheck": ["ok"], "integrityCheck": ["ok"], "foreignKeyViolations": 0},
            },
            "migrations": {"count": 1, "ordered": [latest], "latest": latest, "sha256": "a" * 64},
            "settings": {
                "nonRateLimitSettingsSha256": self.expected["productionBaseline"]["nonRateLimitSettingsSha256"],
                "sha256": "b" * 64,
                "rateLimits": {
                    **copy.deepcopy(self.expected["rateLimitsBefore"]),
                    "count": 11,
                    "sha256": "c" * 64,
                },
            },
            "collections": {
                "fingerprints": {name: (str(index) * 64)[:64] for index, name in enumerate(TABLES, 1)},
                "structuralFingerprints": {
                    name: (f"{index:x}" * 64)[:64]
                    for index, name in enumerate(TABLES, 1)
                },
                "rules": {
                    "zar_workspaces": {
                        "present": True,
                        "rules": _rules(self.expected["workspaceUpdateRuleBefore"], None),
                    },
                    "zar_cash_entries": {"present": True, "rules": _rules(None, None)},
                    "zar_restore_receipts": {"present": False, "rules": None},
                },
            },
            "domainTables": {
                name: {"count": index, "contentSha256": (f"{index:x}" * 64)[:64]}
                for index, name in enumerate(TABLES, 1)
            },
            "restoreReceipts": {"present": False, "count": 0, "metadataSha256": None},
        }

    def _after(self, baseline: dict[str, object], receipt_count: int = 0) -> dict[str, object]:
        state = copy.deepcopy(baseline)
        candidate = self.expected["artifacts"]["migration"]["name"]
        state["migrations"] = {
            "count": 2,
            "ordered": [*baseline["migrations"]["ordered"], candidate],
            "latest": candidate,
            "sha256": "d" * 64,
        }
        state["settings"]["rateLimits"] = {
            **copy.deepcopy(self.expected["rateLimitsAfter"]),
            "count": 13,
            "sha256": "e" * 64,
        }
        state["collections"]["rules"]["zar_workspaces"]["rules"]["updateRule"] = self.expected["workspaceUpdateRuleLocked"]
        state["collections"]["rules"]["zar_restore_receipts"] = {
            "present": True,
            "rules": {key: None for key in RULE_KEYS},
        }
        state["collections"]["fingerprints"]["zar_workspaces"] = "f" * 64
        state["collections"]["fingerprints"]["zar_restore_receipts"] = "9" * 64
        state["collections"]["structuralFingerprints"]["zar_restore_receipts"] = "0" * 64
        state["restoreReceipts"] = {
            "present": True,
            "count": receipt_count,
            "metadataSha256": "8" * 64,
        }
        return state

    def _run(
        self,
        state: dict[str, object],
        profile: str,
        *,
        baseline: dict[str, object] | None = None,
        expected_receipts: int | None = None,
    ) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state_path = root / "state.json"
            state_path.write_text(json.dumps(state), encoding="utf-8")
            command = [
                sys.executable,
                str(GUARD),
                "--state",
                str(state_path),
                "--expected",
                str(EXPECTED),
                "--profile",
                profile,
            ]
            if baseline is not None:
                baseline_path = root / "baseline.json"
                baseline_path.write_text(json.dumps(baseline), encoding="utf-8")
                command.extend(["--baseline", str(baseline_path)])
            if expected_receipts is not None:
                command.extend(["--expected-receipt-count", str(expected_receipts)])
            return subprocess.run(command, capture_output=True, text=True, check=False)

    def test_valid_before_after_contained_and_rolled_back_profiles(self) -> None:
        baseline = self._baseline()
        self.assertEqual(self._run(baseline, "before", expected_receipts=0).returncode, 0)
        after = self._after(baseline)
        self.assertEqual(self._run(after, "after", baseline=baseline, expected_receipts=0).returncode, 0)
        contained = self._after(baseline, receipt_count=1)
        self.assertEqual(self._run(contained, "contained").returncode, 0)
        rolled_back = copy.deepcopy(baseline)
        rolled_back["collections"]["rules"]["zar_workspaces"]["rules"]["updateRule"] = self.expected["workspaceUpdateRuleLocked"]
        rolled_back["collections"]["fingerprints"]["zar_workspaces"] = "f" * 64
        self.assertEqual(self._run(rolled_back, "rolled-back", baseline=baseline, expected_receipts=0).returncode, 0)

    def test_rejects_policy_domain_cash_and_receipt_privacy_drift(self) -> None:
        baseline = self._baseline()
        after = self._after(baseline)
        variants = []
        policy = copy.deepcopy(after)
        policy["settings"]["rateLimits"]["rules"][0]["maxRequests"] += 1
        variants.append(policy)
        non_rate_settings = copy.deepcopy(after)
        non_rate_settings["settings"]["nonRateLimitSettingsSha256"] = "0" * 64
        variants.append(non_rate_settings)
        domain = copy.deepcopy(after)
        domain["domainTables"]["zar_people"]["contentSha256"] = "0" * 64
        variants.append(domain)
        cash = copy.deepcopy(after)
        cash["collections"]["rules"]["zar_cash_entries"]["rules"]["deleteRule"] = ""
        variants.append(cash)
        receipts = copy.deepcopy(after)
        receipts["collections"]["rules"]["zar_restore_receipts"]["rules"]["viewRule"] = ""
        variants.append(receipts)
        extra_collection = copy.deepcopy(after)
        extra_collection["collections"]["fingerprints"]["unexpected"] = "1" * 64
        extra_collection["collections"]["structuralFingerprints"]["unexpected"] = "2" * 64
        variants.append(extra_collection)
        workspace_structure = copy.deepcopy(after)
        workspace_structure["collections"]["structuralFingerprints"]["zar_workspaces"] = "3" * 64
        variants.append(workspace_structure)
        workspace_rule = copy.deepcopy(after)
        workspace_rule["collections"]["rules"]["zar_workspaces"]["rules"]["deleteRule"] = ""
        variants.append(workspace_rule)
        for variant in variants:
            with self.subTest():
                result = self._run(variant, "after", baseline=baseline)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("zar_people", result.stdout)

    def test_after_requires_baseline_but_contained_does_not(self) -> None:
        baseline = self._baseline()
        after = self._after(baseline, receipt_count=1)
        self.assertNotEqual(self._run(after, "after", expected_receipts=1).returncode, 0)
        self.assertEqual(self._run(after, "contained", expected_receipts=1).returncode, 0)


if __name__ == "__main__":
    unittest.main()
