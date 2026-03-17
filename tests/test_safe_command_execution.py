#!/usr/bin/env python3
"""Tests for safe command execution in recovery and cert inventory scripts."""

import importlib.util
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]


def _load_module(module_name: str, relative_path: str):
    module_path = ROOT / relative_path
    spec = importlib.util.spec_from_file_location(module_name, module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load module: {module_name}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


cert_inventory = _load_module("cert_inventory", "utils/cert_inventory.py")
phoenix_progressive = _load_module(
    "phoenix_progressive",
    "scripts/recovery/phoenix_progressive.py",
)


class TestCertInventoryCommandSafety(unittest.TestCase):
    @patch("subprocess.run")
    def test_cert_inventory_run_command_uses_argument_lists(self, mock_run):
        mock_run.return_value = subprocess.CompletedProcess(
            args=["openssl", "version"],
            returncode=0,
            stdout="OpenSSL 3.0",
            stderr="",
        )
        tool = cert_inventory.PhoenixGuardCertInventory(cert_dir=str(ROOT))

        result = tool.run_command(["openssl", "version"])

        self.assertEqual(result.returncode, 0)
        args, kwargs = mock_run.call_args
        self.assertEqual(args[0], ["openssl", "version"])
        self.assertNotIn("shell", kwargs)
        self.assertTrue(kwargs["capture_output"])
        self.assertTrue(kwargs["text"])


class TestProgressiveRecoveryCommandSafety(unittest.TestCase):
    @patch("subprocess.run")
    def test_progressive_recovery_run_command_uses_argument_lists(self, mock_run):
        mock_run.return_value = subprocess.CompletedProcess(
            args=["make", "scan-bootkits"],
            returncode=0,
            stdout="ok",
            stderr="",
        )
        recovery = phoenix_progressive.PhoenixProgressiveRecovery()

        stdout, stderr, returncode = recovery.run_command(["make", "scan-bootkits"])

        self.assertEqual((stdout, stderr, returncode), ("ok", "", 0))
        args, kwargs = mock_run.call_args
        self.assertEqual(args[0], ["make", "scan-bootkits"])
        self.assertNotIn("shell", kwargs)
        self.assertTrue(kwargs["capture_output"])
        self.assertTrue(kwargs["text"])


if __name__ == "__main__":
    unittest.main()
