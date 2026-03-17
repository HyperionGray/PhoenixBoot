#!/usr/bin/env python3
"""Regression tests for safe command execution and planfile output."""

import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PROGRESSIVE_PATH = REPO_ROOT / "scripts" / "recovery" / "phoenix_progressive.py"
CERT_INVENTORY_PATH = REPO_ROOT / "utils" / "cert_inventory.py"


def load_module(module_name: str, module_path: Path):
    spec = importlib.util.spec_from_file_location(module_name, module_path)
    module = importlib.util.module_from_spec(spec)
    assert spec is not None and spec.loader is not None
    spec.loader.exec_module(module)
    return module


class TestProgressivePlanfile(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.progressive_module = load_module("phoenix_progressive", PROGRESSIVE_PATH)

    def test_dry_run_writes_valid_planfile(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            plan_path = temp_path / "plans" / "plan.json"
            original_cwd = os.getcwd()
            try:
                os.chdir(temp_path)
                recovery = self.progressive_module.PhoenixProgressiveRecovery(
                    dry_run=True,
                    auto_yes=True,
                    plan_out=str(plan_path),
                )
                recovery.run_progressive_recovery()
            finally:
                os.chdir(original_cwd)

            self.assertTrue(plan_path.exists())
            plan = json.loads(plan_path.read_text(encoding="utf-8"))

            for key in ("tool", "run", "levels", "outputs"):
                self.assertIn(key, plan)
            for key in ("name", "version"):
                self.assertIn(key, plan["tool"])
            for key in ("run_id", "created_utc", "dry_run"):
                self.assertIn(key, plan["run"])

            self.assertIsInstance(plan["levels"], list)
            self.assertGreaterEqual(len(plan["levels"]), 1)
            self.assertEqual(str(plan_path), plan["outputs"]["plan_path"])

    def test_dry_run_skips_execution(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            plan_path = Path(temp_dir) / "plans" / "plan.json"
            recovery = self.progressive_module.PhoenixProgressiveRecovery(
                dry_run=True,
                auto_yes=True,
                plan_out=str(plan_path),
            )
            _, _, returncode = recovery.run_command(["definitely-not-a-real-command"])
            self.assertEqual(returncode, 0)


class TestCertInventoryCommandSafety(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cert_module = load_module("cert_inventory", CERT_INVENTORY_PATH)

    def test_run_command_uses_argument_list(self):
        inventory = self.cert_module.PhoenixGuardCertInventory(cert_dir="/tmp")
        result = inventory.run_command(["python3", "-c", "print('ok')"])
        self.assertEqual(result.returncode, 0)
        self.assertIn("ok", result.stdout)


if __name__ == "__main__":
    unittest.main()
