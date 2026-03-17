#!/usr/bin/env python3
"""Unit tests for safe command execution in phoenix_progressive.py."""

import importlib.util
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch


MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "recovery" / "phoenix_progressive.py"
SPEC = importlib.util.spec_from_file_location("phoenix_progressive", MODULE_PATH)
phoenix_progressive = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(phoenix_progressive)


class PhoenixProgressiveCommandTests(unittest.TestCase):
    def setUp(self):
        self.recovery = phoenix_progressive.PhoenixProgressiveRecovery()

    def test_run_command_list_executes_without_shell(self):
        with patch.object(phoenix_progressive.subprocess, "run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(
                args=["echo", "ok"], returncode=0, stdout="ok\n", stderr=""
            )

            stdout, stderr, returncode = self.recovery.run_command(["echo", "ok"])

            self.assertEqual(stdout, "ok\n")
            self.assertEqual(stderr, "")
            self.assertEqual(returncode, 0)

            called_args, called_kwargs = mock_run.call_args
            self.assertEqual(called_args[0], ["echo", "ok"])
            self.assertNotIn("shell", called_kwargs)

    def test_run_command_string_is_parsed_without_shell(self):
        with patch.object(phoenix_progressive.subprocess, "run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(
                args=["echo", "hello world"], returncode=0, stdout="hello world\n", stderr=""
            )

            self.recovery.run_command("echo 'hello world'")
            called_args, called_kwargs = mock_run.call_args

            self.assertEqual(called_args[0], ["echo", "hello world"])
            self.assertNotIn("shell", called_kwargs)

    def test_run_command_failure_returns_subprocess_streams(self):
        with patch.object(phoenix_progressive.subprocess, "run") as mock_run:
            mock_run.side_effect = subprocess.CalledProcessError(
                returncode=2,
                cmd=["false"],
                output="failure-out",
                stderr="failure-err",
            )

            stdout, stderr, returncode = self.recovery.run_command(["false"], check=False)

            self.assertEqual(stdout, "failure-out")
            self.assertEqual(stderr, "failure-err")
            self.assertEqual(returncode, 2)

    def test_shell_metacharacters_are_not_interpreted_by_shell(self):
        with patch.object(phoenix_progressive.subprocess, "run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(
                args=["echo", "safe;", "touch", "/tmp/pwn"], returncode=0, stdout="", stderr=""
            )

            self.recovery.run_command("echo safe; touch /tmp/pwn")
            called_args, called_kwargs = mock_run.call_args

            self.assertEqual(called_args[0], ["echo", "safe;", "touch", "/tmp/pwn"])
            self.assertNotIn("shell", called_kwargs)


if __name__ == "__main__":
    unittest.main()
