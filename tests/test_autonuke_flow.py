#!/usr/bin/env python3
import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
AUTONUKE_DIR = REPO_ROOT / "components" / "workflows" / "scripts" / "recovery"
sys.path.insert(0, str(AUTONUKE_DIR))

from autonuke import AutoNuke  # noqa: E402


class AutoNukeFlowTests(unittest.TestCase):
    def setUp(self):
        self.autonuke = AutoNuke()

    def test_first_release_levels_match_requested_order(self):
        level_names = [name for name, _ in self.autonuke.get_recovery_levels()]
        self.assertEqual(
            level_names,
            [
                "☠ FLASHROM",
                "☠ KEXEC",
                "☠ ESP-CD",
                "☠ UUEFI",
                "☠ UUEFI-NUKE",
                "☠ CMOS",
                "☠ CH341A",
            ],
        )

    def test_secureboot_resilience_message_points_to_cli_flags(self):
        message = self.autonuke.get_secureboot_resilience_message()
        self.assertIn("./pf.py kernel-profile-permissive", message)
        self.assertIn("sudo ./pf.py secureboot-enable-kexec", message)
        self.assertIn("./pf.py kernel-profile-hardened", message)
        self.assertIn("PROFILE=hardened ./pf.py kernel-profile-compare", message)

    def test_project_root_detection_finds_repo_root(self):
        self.assertTrue((self.autonuke.project_root / "pf.py").exists())
        self.assertEqual(self.autonuke.project_root, REPO_ROOT)


if __name__ == "__main__":
    unittest.main()
