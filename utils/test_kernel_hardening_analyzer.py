#!/usr/bin/env python3

import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from kernel_config_remediation import KernelConfigRemediator
from kernel_hardening_analyzer import KernelHardeningAnalyzer
from kernel_hardening_policy import HARDENING_CHECKS


class TestKernelHardeningAnalyzer(unittest.TestCase):
    def test_analyze_uses_extracted_policy_checks(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            config_path = Path(temp_dir) / "kernel.config"
            config_path.write_text(
                "\n".join(
                    [
                        "CONFIG_SECURITY_LOCKDOWN_LSM=y",
                        "CONFIG_MODULE_SIG=y",
                        "CONFIG_SECURITY=y",
                        "# CONFIG_KEXEC is not set",
                    ]
                )
            )
            analyzer = KernelHardeningAnalyzer(config_path)
            self.assertTrue(analyzer.load_config(config_path))
            results = analyzer.analyze()

            self.assertEqual(results["total_checks"], len(HARDENING_CHECKS))
            self.assertGreater(results["passed"], 0)
            self.assertIn("Boot Security", results["categories"])
            self.assertIn("Access Control", results["categories"])

    def test_generate_hardened_baseline_keeps_expected_entries(self):
        baseline = KernelHardeningAnalyzer().generate_hardened_baseline()
        self.assertIn("# === Boot Security ===", baseline)
        self.assertIn("CONFIG_SECURITY_LOCKDOWN_LSM=y", baseline)
        self.assertIn("# CONFIG_KEXEC is not set", baseline)

    def test_remediation_still_loads_baseline_from_analyzer(self):
        baseline = KernelConfigRemediator().load_baseline_from_analyzer()
        self.assertEqual(baseline["CONFIG_SECURITY_LOCKDOWN_LSM"], "y")
        self.assertEqual(baseline["CONFIG_KEXEC"], "n")


if __name__ == "__main__":
    unittest.main()
