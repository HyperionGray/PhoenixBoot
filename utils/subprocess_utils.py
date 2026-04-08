#!/usr/bin/env python3
"""Shared helpers for safe subprocess execution without shell=True."""

from __future__ import annotations

import shlex
import subprocess
from pathlib import Path
from typing import Mapping, Sequence


Command = Sequence[str]


def format_command(cmd: Command, use_sudo: bool = False) -> str:
    """Render a command list as a shell-escaped string for logs."""
    parts = ["sudo", *cmd] if use_sudo else list(cmd)
    return " ".join(shlex.quote(part) for part in parts)


def run_command(
    cmd: Command,
    *,
    check: bool = True,
    capture_output: bool = True,
    text: bool = True,
    cwd: str | Path | None = None,
    env: Mapping[str, str] | None = None,
    use_sudo: bool = False,
) -> subprocess.CompletedProcess[str]:
    """Run a command using argument lists to avoid shell injection risks."""
    if not cmd:
        raise ValueError("Command cannot be empty")

    command = ["sudo", *cmd] if use_sudo else list(cmd)
    return subprocess.run(
        command,
        check=check,
        capture_output=capture_output,
        text=text,
        cwd=str(cwd) if cwd is not None else None,
        env=dict(env) if env is not None else None,
    )
