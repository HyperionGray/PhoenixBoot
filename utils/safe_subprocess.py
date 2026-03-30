#!/usr/bin/env python3
"""
Shared safe subprocess helpers for PhoenixBoot tooling.

This module centralizes command normalization, execution, and error
reporting so scripts can avoid shell-based command execution.
"""

from __future__ import annotations

import logging
import shlex
import subprocess
from pathlib import Path
from typing import Optional, Sequence, Union

Command = Union[str, Sequence[str]]


class CommandExecutionError(RuntimeError):
    """Raised when a subprocess invocation fails in a controlled way."""


def normalize_command(command: Command) -> list[str]:
    """Convert a command string or sequence into argv form."""
    if isinstance(command, str):
        argv = shlex.split(command)
    else:
        argv = [str(part) for part in command]

    if not argv:
        raise ValueError("Command must not be empty")
    return argv


def format_command(argv: Sequence[str]) -> str:
    """Return a shell-safe printable representation of argv."""
    return " ".join(shlex.quote(part) for part in argv)


def run_command(
    command: Command,
    *,
    check: bool = True,
    capture_output: bool = True,
    text: bool = True,
    cwd: Optional[Union[str, Path]] = None,
    timeout: Optional[int] = None,
    logger: Optional[logging.Logger] = None,
) -> subprocess.CompletedProcess:
    """Run a command without shell invocation, with consistent logging."""
    argv = normalize_command(command)
    printable = format_command(argv)

    if logger:
        logger.info("Running command: %s", printable)

    try:
        return subprocess.run(
            argv,
            check=check,
            capture_output=capture_output,
            text=text,
            cwd=str(cwd) if isinstance(cwd, Path) else cwd,
            timeout=timeout,
        )
    except FileNotFoundError as exc:
        message = f"Command executable not found: {argv[0]}"
        if logger:
            logger.error(message)
        raise CommandExecutionError(message) from exc
    except subprocess.TimeoutExpired as exc:
        timeout_value = exc.timeout if exc.timeout is not None else timeout
        message = f"Command timed out after {timeout_value}s: {printable}"
        if logger:
            logger.error(message)
        raise CommandExecutionError(message) from exc
    except subprocess.CalledProcessError as exc:
        stderr = (exc.stderr or "").strip()
        message = f"Command failed with exit code {exc.returncode}: {printable}"
        if stderr:
            message = f"{message} | stderr: {stderr}"
        if logger:
            logger.error(message)
        raise CommandExecutionError(message) from exc
