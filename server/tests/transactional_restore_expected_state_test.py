from __future__ import annotations

import hashlib
import importlib.util
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "server" / "scripts" / "transactional_restore_expected_state.json"
LINEAGE_PATH = ROOT / "server" / "tests" / "pocketbase_migration_lineage_test.py"


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class TransactionalRestoreExpectedStateTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        spec = importlib.util.spec_from_file_location("lineage", LINEAGE_PATH)
        assert spec is not None and spec.loader is not None
        cls.lineage = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.lineage)

    def test_candidate_artifact_hashes_match_repository_files(self) -> None:
        artifacts = self.manifest["artifacts"]
        paths = {
            "migration": ROOT / "server" / "pb_migrations" / artifacts["migration"]["name"],
            "helperHook": ROOT / "server" / "pb_hooks" / artifacts["helperHook"]["name"],
            "routeHook": ROOT / "server" / "pb_hooks" / artifacts["routeHook"]["name"],
            "productionUnitOverlay": ROOT / "server" / "deploy" / "zar-server-transactional-restore.conf",
            "stateTool": ROOT / "server" / "scripts" / artifacts["stateTool"]["name"],
            "stateGuard": ROOT / "server" / "scripts" / artifacts["stateGuard"]["name"],
            "canary": ROOT / "server" / "scripts" / artifacts["canary"]["name"],
        }
        for key, path in paths.items():
            with self.subTest(key=key):
                self.assertTrue(path.is_file())
                self.assertEqual(_sha256(path), artifacts[key]["sha256"])

    def test_rate_profiles_are_independent_exact_11_to_13_policy(self) -> None:
        before = self.manifest["rateLimitsBefore"]
        after = self.manifest["rateLimitsAfter"]
        self.assertTrue(before["enabled"])
        self.assertEqual(before["excludedIPs"], [])
        self.assertEqual(len(before["rules"]), 11)
        self.assertEqual(after["rules"][:11], before["rules"])
        self.assertEqual(len(after["rules"]), 13)
        self.assertEqual(after["rules"], self.lineage.EXPECTED_RATE_RULES)
        self.assertEqual(
            [rule["label"] for rule in after["rules"][-2:]],
            ["/api/zar/restore/state", "/api/zar/restore/commit"],
        )

    def test_manifest_pins_current_production_boundary(self) -> None:
        baseline = self.manifest["productionBaseline"]
        self.assertEqual(baseline["latestMigration"], "1793437200_enable_rate_limits.js")
        self.assertRegex(self.manifest["pocketBaseSha256"], r"^[a-f0-9]{64}$")
        self.assertRegex(baseline["unitSha256"], r"^[a-f0-9]{64}$")
        self.assertRegex(baseline["hardeningDropInSha256"], r"^[a-f0-9]{64}$")
        self.assertEqual(
            baseline["nonRateLimitSettingsSha256"],
            "31e444369553958ce6ab820173f71d10257ea3b69ac430a0d2c6ea79e212fc43",
        )
        self.assertNotEqual(
            self.manifest["workspaceUpdateRuleBefore"],
            self.manifest["workspaceUpdateRuleLocked"],
        )

    def test_guarded_tools_pin_the_manifest_hash(self) -> None:
        manifest_hash = _sha256(MANIFEST_PATH)
        for name in (
            "guarded_transactional_restore_deploy.sh",
            "guarded_transactional_restore_rollback.sh",
            "guarded_transactional_restore_contain.sh",
        ):
            with self.subTest(name=name):
                source = (ROOT / "server" / "scripts" / name).read_text(encoding="utf-8")
                self.assertIn(
                    f"readonly pinned_expected_manifest_sha={manifest_hash}",
                    source,
                )


if __name__ == "__main__":
    unittest.main()
