#!/usr/bin/env python3
"""
Tests for DoD/disa_stig_helper.py – specifically the PROFILE env-var
validation introduced to prevent uncaught ValueError from
generate_config_fragment() when an invalid profile is supplied via the
PROFILE environment variable.
"""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path
from unittest import mock

import pytest

# Ensure the repo root is importable so that the relative imports inside
# disa_stig_helper work correctly.
REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT))

from DoD.disa_stig_helper import generate_secure_config, PROFILE_CHOICES
from utils.kernel_config_profiles import KERNEL_PROFILES


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _output_path(tmp_path: Path) -> Path:
    return tmp_path / "out" / "secure_kernel.config"


# ---------------------------------------------------------------------------
# generate_secure_config – PROFILE env-var validation
# ---------------------------------------------------------------------------


class TestProfileEnvValidation:
    """PROFILE env-var takes effect only when --profile is not supplied."""

    def test_invalid_profile_env_returns_1(self, tmp_path: Path, capsys):
        """PROFILE=bogus with no --profile arg must return exit code 1."""
        with mock.patch.dict(os.environ, {"PROFILE": "bogus"}, clear=False):
            result = generate_secure_config(_output_path(tmp_path), None, None)
        assert result == 1
        captured = capsys.readouterr()
        assert "bogus" in captured.err
        assert "PROFILE environment variable" in captured.err

    def test_invalid_profile_env_message_lists_available_profiles(self, tmp_path: Path, capsys):
        """Error message must mention all available profiles."""
        with mock.patch.dict(os.environ, {"PROFILE": "bogus"}, clear=False):
            generate_secure_config(_output_path(tmp_path), None, None)
        captured = capsys.readouterr()
        for profile_name in PROFILE_CHOICES:
            assert profile_name in captured.err

    def test_valid_profile_env_succeeds(self, tmp_path: Path):
        """PROFILE=balanced with no --profile arg must succeed (return 0)."""
        with mock.patch.dict(os.environ, {"PROFILE": "balanced"}, clear=False):
            result = generate_secure_config(_output_path(tmp_path), None, None)
        assert result == 0
        assert _output_path(tmp_path).exists()

    def test_arg_wins_over_invalid_profile_env(self, tmp_path: Path):
        """--profile hardened must override PROFILE=bogus and succeed."""
        with mock.patch.dict(os.environ, {"PROFILE": "bogus"}, clear=False):
            result = generate_secure_config(_output_path(tmp_path), None, "hardened")
        assert result == 0
        assert _output_path(tmp_path).exists()

    def test_no_env_no_arg_falls_back_to_distro_default(self, tmp_path: Path):
        """Without PROFILE env or --profile arg the distro default is used."""
        env = {k: v for k, v in os.environ.items() if k != "PROFILE"}
        with mock.patch.dict(os.environ, env, clear=True):
            result = generate_secure_config(_output_path(tmp_path), None, None)
        assert result == 0
        assert _output_path(tmp_path).exists()


# ---------------------------------------------------------------------------
# PROFILE_CHOICES consistency check
# ---------------------------------------------------------------------------


class TestProfileChoicesConsistency:
    """PROFILE_CHOICES must stay in sync with KERNEL_PROFILES."""

    def test_profile_choices_match_kernel_profiles(self):
        assert set(PROFILE_CHOICES) == set(KERNEL_PROFILES.keys())

    def test_profile_choices_non_empty(self):
        assert len(PROFILE_CHOICES) > 0


# ---------------------------------------------------------------------------
# generate_secure_config – output file
# ---------------------------------------------------------------------------


class TestGenerateSecureConfigOutput:
    """Generated file should contain a recognisable header."""

    @pytest.mark.parametrize("profile", list(KERNEL_PROFILES.keys()))
    def test_output_file_written_for_each_profile(self, tmp_path: Path, profile: str):
        result = generate_secure_config(_output_path(tmp_path), None, profile)
        assert result == 0
        content = _output_path(tmp_path).read_text()
        assert "PhoenixBoot DoD helper output" in content

    def test_output_directory_created_if_missing(self, tmp_path: Path):
        deep_output = tmp_path / "a" / "b" / "c" / "secure_kernel.config"
        result = generate_secure_config(deep_output, None, "hardened")
        assert result == 0
        assert deep_output.exists()
