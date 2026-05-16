#!/usr/bin/env python3

"""Regression tests for documented public API surfaces in utils/."""

import importlib
import os
import sys
import unittest
from pathlib import Path


UTILS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, os.fspath(UTILS_DIR))


class TestPythonPublicApiDocs(unittest.TestCase):
    """Ensure importable modules expose documented public API entry points."""

    def test_cert_inventory_public_api_docstrings(self):
        module = importlib.import_module("cert_inventory")
        self.assertEqual(module.__all__, ["PhoenixGuardCertInventory", "main"])
        self.assertIn("Public API", module.__doc__)
        self.assertIn("inventory", module.PhoenixGuardCertInventory.__doc__.lower())
        self.assertIn("JSON", module.PhoenixGuardCertInventory.save_inventory.__doc__)

    def test_pgmodsign_public_api_docstrings(self):
        module = importlib.import_module("pgmodsign")
        self.assertEqual(module.__all__, ["PhoenixGuardModuleSigner", "main"])
        self.assertIn("Public API", module.__doc__)
        self.assertIn("kernel modules", module.PhoenixGuardModuleSigner.__doc__)
        self.assertIn("result dictionary", module.PhoenixGuardModuleSigner.sign_multiple_modules.__doc__)


class TestHeaderPublicApiDocs(unittest.TestCase):
    """Ensure the installable C header explains the verification lifecycle."""

    def test_pgmodverify_header_documents_library_lifecycle(self):
        header_text = (UTILS_DIR / "pgmodverify.h").read_text(encoding="utf-8")
        self.assertIn("installable public API", header_text)
        self.assertIn("pg_cleanup()", header_text)
        self.assertIn("Call this once before verification", header_text)
        self.assertIn("Verify a single kernel module", header_text)


if __name__ == "__main__":
    unittest.main()
