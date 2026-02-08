#!/usr/bin/env python3
"""
PhoenixBoot TUI - Interactive Terminal User Interface

A modern text-based interface for managing PhoenixBoot operations.
This provides a unified, user-friendly way to interact with all PhoenixBoot
functionality including building, testing, key management, and system operations.
"""

import os
import sys
import subprocess
from pathlib import Path
from typing import Optional, List, Dict, Tuple

from textual.app import App, ComposeResult
from textual.containers import Container, Horizontal, Vertical, ScrollableContainer
from textual.widgets import (
    Header, Footer, Button, Static, ListView, ListItem, 
    Label, Markdown, TabbedContent, TabPane, Tree, Log
)
from textual.binding import Binding
from textual.screen import Screen
from rich.text import Text
from rich.console import Console

# Get PhoenixBoot root directory
# Try multiple methods to find the root directory
def find_phoenixboot_root():
    """Find PhoenixBoot root directory by looking for pf.py marker file"""
    current = Path(__file__).parent.absolute()
    
    # Walk up the directory tree looking for pf.py
    for _ in range(5):  # Max 5 levels up
        if (current / "pf.py").exists():
            return current
        current = current.parent
    
    # Fallback: use environment variable if set
    if "PHOENIXBOOT_ROOT" in os.environ:
        return Path(os.environ["PHOENIXBOOT_ROOT"])
    
    # Last resort: assume we're in containers/tui/app
    return Path(__file__).parent.parent.parent.absolute()

PHOENIXBOOT_ROOT = find_phoenixboot_root()
PF_RUNNER = PHOENIXBOOT_ROOT / "pf.py"


class TaskCategory:
    """Represents a category of PhoenixBoot tasks"""
    
    BUILD = "Build & Setup"
    TEST = "Testing & Validation"
    SECUREBOOT = "SecureBoot & Keys"
    MOK = "MOK & Module Signing"
    UUEFI = "UUEFI Operations"
    INSTALLER = "ESP & Bootable Media"
    SECURITY = "Security Analysis"
    MAINTENANCE = "Maintenance"


class TaskExecutor:
    """Handles execution of PhoenixBoot tasks"""
    
    @staticmethod
    def run_task(task_name: str, cwd: Path = PHOENIXBOOT_ROOT) -> Tuple[int, str, str]:
        """Execute a pf.py task and return exit code, stdout, stderr"""
        try:
            result = subprocess.run(
                [str(PF_RUNNER), task_name],
                cwd=str(cwd),
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return 1, "", "Task timed out after 5 minutes"
        except Exception as e:
            return 1, "", f"Error executing task: {str(e)}"
    
    @staticmethod
    def list_tasks() -> List[str]:
        """Get list of all available tasks"""
        try:
            result = subprocess.run(
                [str(PF_RUNNER), "list"],
                cwd=str(PHOENIXBOOT_ROOT),
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                # Parse task list from output
                tasks = []
                for line in result.stdout.split('\n'):
                    line = line.strip()
                    if line and not line.startswith('#') and not line.startswith('Available'):
                        # Extract task name (first word)
                        parts = line.split()
                        if parts:
                            tasks.append(parts[0])
                return tasks
            return []
        except Exception:
            return []


class TaskOutputScreen(Screen):
    """Screen to show task output"""
    
    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
        Binding("q", "app.pop_screen", "Back"),
    ]
    
    def __init__(self, task_name: str, output: str, error: str, exit_code: int):
        super().__init__()
        self.task_name = task_name
        self.output = output
        self.error = error
        self.exit_code = exit_code
    
    def compose(self) -> ComposeResult:
        yield Header()
        
        status = "✓ Success" if self.exit_code == 0 else f"✗ Failed (exit code: {self.exit_code})"
        status_class = "success" if self.exit_code == 0 else "error"
        
        with Container():
            yield Static(f"Task: {self.task_name}", classes="task-title")
            yield Static(status, classes=status_class)
            
            with TabbedContent():
                with TabPane("Output", id="output"):
                    log = Log(auto_scroll=True)
                    log.write_line(self.output if self.output else "(no output)")
                    yield log
                
                with TabPane("Errors", id="errors"):
                    log = Log(auto_scroll=True)
                    log.write_line(self.error if self.error else "(no errors)")
                    yield log
        
        yield Footer()


class PhoenixBootTUI(App):
    """PhoenixBoot Terminal User Interface"""
    
    CSS = """
    Screen {
        background: $surface;
    }
    
    .task-title {
        background: $primary;
        color: $text;
        padding: 1;
        text-align: center;
        text-style: bold;
    }
    
    .success {
        background: $success;
        color: $text;
        padding: 1;
        text-align: center;
    }
    
    .error {
        background: $error;
        color: $text;
        padding: 1;
        text-align: center;
    }
    
    .category-title {
        background: $primary-darken-1;
        color: $text;
        padding: 1;
        text-style: bold;
    }
    
    Button {
        margin: 1;
    }
    
    #sidebar {
        width: 30;
        background: $panel;
        border-right: solid $primary;
    }
    
    #main-content {
        padding: 1;
    }
    
    .info-panel {
        background: $panel;
        border: solid $primary;
        padding: 1;
        margin: 1;
    }
    """
    
    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("d", "toggle_dark", "Toggle Dark Mode"),
    ]
    
    TITLE = "🔥 PhoenixBoot - Secure Boot Defense System"
    SUB_TITLE = "Interactive Management Interface"
    
    def compose(self) -> ComposeResult:
        """Create child widgets for the app."""
        yield Header()
        
        with Horizontal():
            # Sidebar with categories
            with Container(id="sidebar"):
                yield Static("Task Categories", classes="category-title")
                yield Button("🔨 Build & Setup", id="cat-build", variant="primary")
                yield Button("🧪 Testing", id="cat-test", variant="primary")
                yield Button("🔐 SecureBoot", id="cat-secureboot", variant="primary")
                yield Button("🔑 MOK & Signing", id="cat-mok", variant="primary")
                yield Button("🔧 UUEFI", id="cat-uuefi", variant="primary")
                yield Button("💿 Installer", id="cat-installer", variant="primary")
                yield Button("🛡️ Security", id="cat-security", variant="primary")
                yield Button("⚙️ Maintenance", id="cat-maint", variant="primary")
                yield Button("ℹ️ About", id="cat-about", variant="default")
            
            # Main content area
            with ScrollableContainer(id="main-content"):
                yield self.get_welcome_content()
        
        yield Footer()
    
    def get_welcome_content(self) -> Markdown:
        """Get welcome screen markdown"""
        content = """
# Welcome to PhoenixBoot TUI

PhoenixBoot is a production-ready firmware defense system designed to protect 
against bootkits, rootkits, and supply chain attacks.

## Quick Start

Select a category from the sidebar to view available tasks:

- **Build & Setup**: Bootstrap environment and build artifacts
- **Testing**: Run QEMU tests and validation
- **SecureBoot**: Generate keys and manage SecureBoot
- **MOK & Signing**: Module signing and MOK operations
- **UUEFI**: Universal UEFI diagnostic tool
- **Installer**: Create bootable media and ESP images
- **Security**: Security analysis and environment checks
- **Maintenance**: Code formatting, linting, and cleanup

## Keyboard Shortcuts

- `q` - Quit application
- `d` - Toggle dark/light mode
- `Esc` - Go back
- `Tab` - Navigate between elements

## Container-Based Architecture

PhoenixBoot now uses a modular container architecture:
- Each component runs in isolated containers
- Podman quadlet integration for systemd management
- Reproducible builds and consistent paths
- Easy to deploy and maintain

Select a category to get started!
"""
        return Markdown(content)
    
    def get_build_tasks(self) -> Container:
        """Get build & setup tasks"""
        tasks = [
            ("build-setup", "Bootstrap toolchain & environment"),
            ("build-build", "Build production artifacts"),
            ("build-package-esp", "Package bootable ESP image"),
        ]
        return self.create_task_list("Build & Setup Tasks", tasks)
    
    def get_test_tasks(self) -> Container:
        """Get testing tasks"""
        tasks = [
            ("test-qemu", "Main QEMU boot test"),
            ("test-qemu-secure-positive", "SecureBoot positive test"),
            ("test-qemu-uuefi", "UUEFI application test"),
            ("test-qemu-secure-strict", "SecureBoot strict mode"),
            ("test-qemu-secure-negative-attest", "Corruption detection test"),
        ]
        return self.create_task_list("Testing & Validation", tasks)
    
    def get_secureboot_tasks(self) -> Container:
        """Get SecureBoot tasks"""
        tasks = [
            ("secure-keygen", "Generate SecureBoot keys (PK, KEK, db)"),
            ("secure-make-auth", "Create authenticated variable files"),
            ("secureboot-create", "Create SecureBoot bootable media"),
            ("secure-enroll-secureboot", "Enroll SecureBoot keys into QEMU OVMF"),
        ]
        return self.create_task_list("SecureBoot & Key Management", tasks)
    
    def get_mok_tasks(self) -> Container:
        """Get MOK tasks"""
        tasks = [
            ("secure-mok-new", "Generate new MOK certificate"),
            ("os-mok-enroll", "Enroll MOK certificate"),
            ("os-mok-list-keys", "List enrolled MOK keys"),
            ("secure-mok-verify", "Verify a MOK certificate"),
            ("secure-enroll-mok", "Enroll PhoenixGuard MOK certificate"),
            ("os-kmod-sign", "Sign kernel module"),
        ]
        return self.create_task_list("MOK & Module Signing", tasks)
    
    def get_uuefi_tasks(self) -> Container:
        """Get UUEFI tasks"""
        tasks = [
            ("uuefi-install", "Install UUEFI.efi to ESP"),
            ("uuefi-apply", "Set BootNext for UUEFI"),
            ("uuefi-report", "Display system security status"),
        ]
        return self.create_task_list("UUEFI Operations", tasks)
    
    def get_installer_tasks(self) -> Container:
        """Get installer tasks"""
        tasks = [
            ("build-package-esp", "Package ESP image"),
            ("esp", "Complete ESP build & package"),
            ("validate-all", "Validate all artifacts"),
        ]
        return self.create_task_list("ESP & Bootable Media", tasks)
    
    def get_security_tasks(self) -> Container:
        """Get security tasks"""
        tasks = [
            ("secure-env", "Comprehensive security check"),
            ("kernel-hardening-check", "Kernel hardening analysis"),
            ("kernel-hardening-report", "Generate hardening report"),
            ("firmware-checksum-list", "List firmware checksums"),
        ]
        return self.create_task_list("Security Analysis", tasks)
    
    def get_maint_tasks(self) -> Container:
        """Get maintenance tasks"""
        tasks = [
            ("cleanup", "Clean build artifacts"),
            ("verify", "Verify artifacts"),
        ]
        return self.create_task_list("Maintenance Tasks", tasks)
    
    def get_about_content(self) -> Markdown:
        """Get about screen"""
        content = """
# About PhoenixBoot

## Version Information

- **Project**: PhoenixBoot (PhoenixGuard)
- **License**: Apache 2.0
- **Repository**: https://github.com/P4X-ng/PhoenixBoot

## Features

### ✅ Implemented
- Nuclear Boot (NuclearBootEdk2)
- Key Enrollment (KeyEnrollEdk2)
- UUEFI Diagnostic Tool v3.0
- Secure Boot key management
- MOK and module signing
- Security environment checks
- Kernel hardening analysis
- QEMU testing framework

### 🚧 In Progress
- Hardware firmware recovery
- Xen hypervisor integration
- Cloud attestation API

## Container Architecture

PhoenixBoot uses a modular container-based architecture:

- **Build Container**: EDK2 compilation and artifact building
- **Test Container**: QEMU tests and validation
- **Installer Container**: ESP manipulation and bootable media
- **Runtime Container**: On-host operations
- **TUI Container**: This interactive interface

Each container is managed via Podman quadlets for systemd integration.

## Support

- **Documentation**: `docs/` directory
- **Issues**: https://github.com/P4X-ng/PhoenixBoot/issues
- **Quick Start**: See README.md

---

Made with 🔥 for a more secure boot process
"""
        return Markdown(content)
    
    def create_task_list(self, title: str, tasks: List[Tuple[str, str]]) -> Container:
        """Create a task list container"""
        container = Container()
        container.mount(Static(title, classes="category-title"))
        
        for task_id, description in tasks:
            button = Button(f"{task_id}", id=f"task-{task_id}", variant="default")
            button.tooltip = description
            container.mount(button)
        
        return container
    
    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses"""
        button_id = event.button.id
        
        if button_id == "cat-build":
            self.show_category_tasks("build")
        elif button_id == "cat-test":
            self.show_category_tasks("test")
        elif button_id == "cat-secureboot":
            self.show_category_tasks("secureboot")
        elif button_id == "cat-mok":
            self.show_category_tasks("mok")
        elif button_id == "cat-uuefi":
            self.show_category_tasks("uuefi")
        elif button_id == "cat-installer":
            self.show_category_tasks("installer")
        elif button_id == "cat-security":
            self.show_category_tasks("security")
        elif button_id == "cat-maint":
            self.show_category_tasks("maint")
        elif button_id == "cat-about":
            self.show_about()
        elif button_id and button_id.startswith("task-"):
            # Extract task name and execute
            task_name = button_id[5:]  # Remove "task-" prefix
            self.execute_task(task_name)
    
    def show_category_tasks(self, category: str) -> None:
        """Show tasks for a specific category"""
        content_area = self.query_one("#main-content")
        content_area.remove_children()
        
        if category == "build":
            content_area.mount(self.get_build_tasks())
        elif category == "test":
            content_area.mount(self.get_test_tasks())
        elif category == "secureboot":
            content_area.mount(self.get_secureboot_tasks())
        elif category == "mok":
            content_area.mount(self.get_mok_tasks())
        elif category == "uuefi":
            content_area.mount(self.get_uuefi_tasks())
        elif category == "installer":
            content_area.mount(self.get_installer_tasks())
        elif category == "security":
            content_area.mount(self.get_security_tasks())
        elif category == "maint":
            content_area.mount(self.get_maint_tasks())
    
    def show_about(self) -> None:
        """Show about screen"""
        content_area = self.query_one("#main-content")
        content_area.remove_children()
        content_area.mount(self.get_about_content())
    
    def execute_task(self, task_name: str) -> None:
        """Execute a PhoenixBoot task"""
        self.notify(f"Executing task: {task_name}...")
        
        # Run task in background
        exit_code, stdout, stderr = TaskExecutor.run_task(task_name)
        
        # Show output screen
        self.push_screen(TaskOutputScreen(task_name, stdout, stderr, exit_code))
    
    def action_toggle_dark(self) -> None:
        """Toggle dark mode"""
        self.dark = not self.dark


def main():
    """Main entry point"""
    app = PhoenixBootTUI()
    app.run()


if __name__ == "__main__":
    main()
