#!/usr/bin/env python3
"""Focused tests for secure command execution in cert_inventory.py."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest
from unittest import mock


def _load_module():
    module_path = Path(__file__).resolve().parents[1] / "utils" / "cert_inventory.py"
    spec = importlib.util.spec_from_file_location("cert_inventory", module_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class CertInventorySecurityTests(unittest.TestCase):
    def test_run_command_uses_argument_list_and_shell_disabled(self):
        cert_inventory = _load_module()
        tool = cert_inventory.PhoenixGuardCertInventory("/tmp")

        completed = mock.Mock()
        completed.stdout = ""
        completed.stderr = ""

        with mock.patch.object(cert_inventory.subprocess, "run", return_value=completed) as run_mock:
            tool.run_command(["openssl", "version"])

        run_mock.assert_called_once()
        args, kwargs = run_mock.call_args

        self.assertEqual(args[0], ["openssl", "version"])
        self.assertFalse(kwargs["shell"])
        self.assertTrue(kwargs["capture_output"])
        self.assertTrue(kwargs["text"])

    def test_inventory_returns_safe_empty_structure_for_missing_directory(self):
        cert_inventory = _load_module()
        tool = cert_inventory.PhoenixGuardCertInventory("/definitely/missing/certs")

        inventory = tool.inventory_all_certificates()

        self.assertEqual(inventory["scan_info"]["total_files_scanned"], 0)
        self.assertEqual(inventory["certificate_details"], [])
        self.assertEqual(inventory["signing_candidates"], [])
        self.assertIn("recommendations", inventory)
        self.assertGreaterEqual(len(inventory["recommendations"]), 1)


if __name__ == "__main__":
    unittest.main()

