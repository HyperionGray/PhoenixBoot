#!/usr/bin/env python3
"""
Tests for DoD/disa_stig_helper.py — specifically the PROFILE env-var
validation added to generate_secure_config().
"""

from __future__ import annotations

import os
import sys
import subprocess
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

# Make sure the repo root is importable so disa_stig_helper can find its deps.
REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT))

from DoD.disa_stig_helper import (
    PROFILE_CHOICES,
    generate_secure_config,
)
from utils.kernel_config_profiles import KERNEL_PROFILES


# ---------------------------------------------------------------------------
# Unit tests — generate_secure_config()
# ---------------------------------------------------------------------------

class TestProfileChoices:
    """PROFILE_CHOICES must stay in sync with KERNEL_PROFILES."""

    def test_choices_match_kernel_profiles(self):
        assert set(PROFILE_CHOICES) == set(KERNEL_PROFILES.keys())

    def test_choices_is_not_empty(self):
        assert len(PROFILE_CHOICES) > 0


class TestGenerateSecureConfig:
    """generate_secure_config validates the resolved profile before generation."""

    def _run(self, tmp_path: Path, env_profile: str | None, cli_profile: str | None):
        """Helper: call generate_secure_config with controlled env + args."""
        output = tmp_path / "kernel.config"
        env: dict[str, str] = os.environ.copy()
        if env_profile is not None:
            env["PROFILE"] = env_profile
        else:
            env.pop("PROFILE", None)

        with patch.dict(os.environ, env, clear=True):
            return generate_secure_config(output, requested_distro=None, requested_profile=cli_profile), output

    # -- Invalid PROFILE env var (no CLI override) ---------------------------

    def test_invalid_profile_env_returns_1(self, tmp_path):
        rc, _ = self._run(tmp_path, env_profile="bogus", cli_profile=None)
        assert rc == 1

    def test_invalid_profile_env_prints_stderr(self, tmp_path, capsys):
        self._run(tmp_path, env_profile="bogus", cli_profile=None)
        captured = capsys.readouterr()
        assert "bogus" in captured.err
        assert "PROFILE environment variable" in captured.err

    def test_invalid_profile_env_lists_available_profiles(self, tmp_path, capsys):
        self._run(tmp_path, env_profile="bogus", cli_profile=None)
        captured = capsys.readouterr()
        for name in KERNEL_PROFILES:
            assert name in captured.err

    def test_invalid_profile_env_does_not_create_output(self, tmp_path):
        _, output = self._run(tmp_path, env_profile="bogus", cli_profile=None)
        assert not output.exists()

    # -- Valid PROFILE env var -----------------------------------------------

    @pytest.mark.parametrize("profile", list(KERNEL_PROFILES.keys()))
    def test_valid_profile_env_returns_0(self, tmp_path, profile):
        rc, _ = self._run(tmp_path, env_profile=profile, cli_profile=None)
        assert rc == 0

    @pytest.mark.parametrize("profile", list(KERNEL_PROFILES.keys()))
    def test_valid_profile_env_creates_output(self, tmp_path, profile):
        _, output = self._run(tmp_path, env_profile=profile, cli_profile=None)
        assert output.exists()

    # -- CLI arg wins over bad PROFILE env var --------------------------------

    def test_cli_arg_wins_over_invalid_env(self, tmp_path):
        """PROFILE=bogus --profile hardened → CLI arg wins; should succeed."""
        rc, output = self._run(tmp_path, env_profile="bogus", cli_profile="hardened")
        assert rc == 0
        assert output.exists()

    # -- No PROFILE env, no CLI arg → falls back to distro default -----------

    def test_no_profile_uses_default(self, tmp_path):
        rc, output = self._run(tmp_path, env_profile=None, cli_profile=None)
        assert rc == 0
        assert output.exists()


# ---------------------------------------------------------------------------
# Subprocess / CLI integration tests
# ---------------------------------------------------------------------------

HELPER = str(REPO_ROOT / "DoD" / "disa_stig_helper.py")


def _cli(*args: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess:
    base_env = os.environ.copy()
    if env:
        base_env.update(env)
    return subprocess.run(
        [sys.executable, HELPER, *args],
        capture_output=True,
        text=True,
        env=base_env,
    )


class TestCLIProfileValidation:
    """End-to-end CLI scenarios from the PR description test matrix."""

    def test_profile_env_bogus_exits_1(self, tmp_path):
        result = _cli(
            "generate-secure-config",
            "--output", str(tmp_path / "out.config"),
            env={"PROFILE": "bogus"},
        )
        assert result.returncode == 1
        assert "bogus" in result.stderr
        assert "PROFILE environment variable" in result.stderr

    def test_profile_env_balanced_exits_0(self, tmp_path):
        result = _cli(
            "generate-secure-config",
            "--output", str(tmp_path / "out.config"),
            env={"PROFILE": "balanced"},
        )
        assert result.returncode == 0

    def test_cli_invalid_profile_exits_2(self, tmp_path):
        """--profile nope is rejected by argparse with exit code 2."""
        result = _cli(
            "generate-secure-config",
            "--profile", "nope",
            "--output", str(tmp_path / "out.config"),
        )
        assert result.returncode == 2

    def test_cli_arg_wins_over_bogus_env(self, tmp_path):
        """PROFILE=bogus --profile hardened → CLI wins, exit 0."""
        result = _cli(
            "generate-secure-config",
            "--profile", "hardened",
            "--output", str(tmp_path / "out.config"),
            env={"PROFILE": "bogus"},
        )
        assert result.returncode == 0
