from dataclasses import dataclass
from enum import Enum
from typing import Optional


class Severity(Enum):
    """Security severity levels"""

    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    INFO = "INFO"


@dataclass
class ConfigCheck:
    """Represents a kernel config security check"""

    name: str
    expected_value: str
    severity: Severity
    category: str
    description: str
    stig_id: Optional[str] = None
    remediation: Optional[str] = None


class ConfigProfile(Enum):
    """Kernel configuration security profiles"""

    HARDENED = "HARDENED"
    PERMISSIVE = "PERMISSIVE"
    TRANSITION = "TRANSITION"


HARDENING_CHECKS = [
    # === Boot Security ===
    ConfigCheck(
        name="CONFIG_SECURITY_LOCKDOWN_LSM",
        expected_value="y",
        severity=Severity.CRITICAL,
        category="Boot Security",
        description="Kernel lockdown LSM prevents runtime modifications to kernel",
        stig_id="RHEL-08-010370",
        remediation="Enable CONFIG_SECURITY_LOCKDOWN_LSM=y and boot with lockdown=integrity",
    ),
    ConfigCheck(
        name="CONFIG_LOCK_DOWN_KERNEL_FORCE_INTEGRITY",
        expected_value="y",
        severity=Severity.HIGH,
        category="Boot Security",
        description="Force kernel lockdown in integrity mode",
        remediation="Enable CONFIG_LOCK_DOWN_KERNEL_FORCE_INTEGRITY=y",
    ),
    ConfigCheck(
        name="CONFIG_MODULE_SIG",
        expected_value="y",
        severity=Severity.CRITICAL,
        category="Boot Security",
        description="Kernel module signature verification",
        stig_id="RHEL-08-010370",
        remediation="Enable CONFIG_MODULE_SIG=y",
    ),
    ConfigCheck(
        name="CONFIG_MODULE_SIG_FORCE",
        expected_value="y",
        severity=Severity.CRITICAL,
        category="Boot Security",
        description="Require all kernel modules to be validly signed",
        stig_id="RHEL-08-010370",
        remediation="Enable CONFIG_MODULE_SIG_FORCE=y",
    ),
    ConfigCheck(
        name="CONFIG_MODULE_SIG_ALL",
        expected_value="y",
        severity=Severity.HIGH,
        category="Boot Security",
        description="Automatically sign all modules",
        remediation="Enable CONFIG_MODULE_SIG_ALL=y",
    ),
    ConfigCheck(
        name="CONFIG_MODULE_SIG_SHA256",
        expected_value="y",
        severity=Severity.MEDIUM,
        category="Boot Security",
        description="Use SHA256 for module signatures (secure)",
        remediation="Enable CONFIG_MODULE_SIG_SHA256=y",
    ),
    ConfigCheck(
        name="CONFIG_KEXEC",
        expected_value="n",
        severity=Severity.HIGH,
        category="Boot Security",
        description="Disable kexec (can bypass secure boot)",
        stig_id="RHEL-08-010372",
        remediation="Disable CONFIG_KEXEC unless specifically needed",
    ),
    ConfigCheck(
        name="CONFIG_HIBERNATION",
        expected_value="n",
        severity=Severity.MEDIUM,
        category="Boot Security",
        description="Disable hibernation (can leak sensitive data)",
        remediation="Disable CONFIG_HIBERNATION",
    ),
    # === Memory Security ===
    ConfigCheck(
        name="CONFIG_STRICT_KERNEL_RWX",
        expected_value="y",
        severity=Severity.CRITICAL,
        category="Memory Protection",
        description="Mark kernel memory segments as read-only or non-executable",
        remediation="Enable CONFIG_STRICT_KERNEL_RWX=y",
    ),
    ConfigCheck(
        name="CONFIG_STRICT_MODULE_RWX",
        expected_value="y",
        severity=Severity.HIGH,
        category="Memory Protection",
        description="Apply strict RWX to kernel modules",
        remediation="Enable CONFIG_STRICT_MODULE_RWX=y",
    ),
    ConfigCheck(
        name="CONFIG_HARDENED_USERCOPY",
        expected_value="y",
        severity=Severity.HIGH,
        category="Memory Protection",
        description="Harden copying data between kernel and userspace",
        remediation="Enable CONFIG_HARDENED_USERCOPY=y",
    ),
    ConfigCheck(
        name="CONFIG_FORTIFY_SOURCE",
        expected_value="y",
        severity=Severity.HIGH,
        category="Memory Protection",
        description="Detect buffer overflows at compile time",
        remediation="Enable CONFIG_FORTIFY_SOURCE=y",
    ),
    ConfigCheck(
        name="CONFIG_PAGE_TABLE_ISOLATION",
        expected_value="y",
        severity=Severity.CRITICAL,
        category="Memory Protection",
        description="Isolate kernel page tables (Meltdown mitigation)",
        remediation="Enable CONFIG_PAGE_TABLE_ISOLATION=y",
    ),
    ConfigCheck(
        name="CONFIG_RANDOMIZE_BASE",
        expected_value="y",
        severity=Severity.CRITICAL,
        category="Memory Protection",
        description="Kernel Address Space Layout Randomization (KASLR)",
        stig_id="RHEL-08-010430",
        remediation="Enable CONFIG_RANDOMIZE_BASE=y",
    ),
    ConfigCheck(
        name="CONFIG_RANDOMIZE_MEMORY",
        expected_value="y",
        severity=Severity.HIGH,
        category="Memory Protection",
        description="Randomize kernel memory sections",
        remediation="Enable CONFIG_RANDOMIZE_MEMORY=y",
    ),
    ConfigCheck(
        name="CONFIG_SLAB_FREELIST_RANDOM",
        expected_value="y",
        severity=Severity.MEDIUM,
        category="Memory Protection",
        description="Randomize slab allocator freelist",
        remediation="Enable CONFIG_SLAB_FREELIST_RANDOM=y",
    ),
    ConfigCheck(
        name="CONFIG_SLAB_FREELIST_HARDENED",
        expected_value="y",
        severity=Severity.MEDIUM,
        category="Memory Protection",
        description="Harden slab allocator freelist",
        remediation="Enable CONFIG_SLAB_FREELIST_HARDENED=y",
    ),
    # === Stack Protection ===
    ConfigCheck(
        name="CONFIG_STACKPROTECTOR",
        expected_value="y",
        severity=Severity.HIGH,
        category="Stack Protection",
        description="Enable stack canary protection",
        remediation="Enable CONFIG_STACKPROTECTOR=y",
    ),
    ConfigCheck(
        name="CONFIG_STACKPROTECTOR_STRONG",
        expected_value="y",
        severity=Severity.HIGH,
        category="Stack Protection",
        description="Use strong stack protector",
        remediation="Enable CONFIG_STACKPROTECTOR_STRONG=y",
    ),
    ConfigCheck(
        name="CONFIG_VMAP_STACK",
        expected_value="y",
        severity=Severity.MEDIUM,
        category="Stack Protection",
        description="Use virtually-mapped kernel stacks",
        remediation="Enable CONFIG_VMAP_STACK=y",
    ),
    # === Access Control ===
    ConfigCheck(
        name="CONFIG_SECURITY",
        expected_value="y",
        severity=Severity.CRITICAL,
        category="Access Control",
        description="Enable Linux Security Module framework",
        remediation="Enable CONFIG_SECURITY=y",
    ),
    ConfigCheck(
        name="CONFIG_SECURITY_SELINUX",
        expected_value="y",
        severity=Severity.HIGH,
        category="Access Control",
        description="Enable SELinux",
        stig_id="RHEL-08-010170",
        remediation="Enable CONFIG_SECURITY_SELINUX=y",
    ),
    ConfigCheck(
        name="CONFIG_SECURITY_APPARMOR",
        expected_value="y",
        severity=Severity.MEDIUM,
        category="Access Control",
        description="Enable AppArmor (alternative to SELinux)",
        remediation="Enable CONFIG_SECURITY_APPARMOR=y if not using SELinux",
    ),
    ConfigCheck(
        name="CONFIG_SECURITY_YAMA",
        expected_value="y",
        severity=Severity.MEDIUM,
        category="Access Control",
        description="Enable Yama LSM (ptrace restrictions)",
        remediation="Enable CONFIG_SECURITY_YAMA=y",
    ),
    # === Debugging Features (should be disabled in production) ===
    ConfigCheck(
        name="CONFIG_DEBUG_FS",
        expected_value="n",
        severity=Severity.HIGH,
        category="Debug Features",
        description="Disable debugfs (exposes kernel internals)",
        remediation="Disable CONFIG_DEBUG_FS in production",
    ),
    ConfigCheck(
        name="CONFIG_KPROBES",
        expected_value="n",
        severity=Severity.MEDIUM,
        category="Debug Features",
        description="Disable kprobes (can be used for rootkits)",
        remediation="Disable CONFIG_KPROBES in production",
    ),
    ConfigCheck(
        name="CONFIG_PROC_KCORE",
        expected_value="n",
        severity=Severity.HIGH,
        category="Debug Features",
        description="Disable /proc/kcore (exposes kernel memory)",
        remediation="Disable CONFIG_PROC_KCORE",
    ),
    ConfigCheck(
        name="CONFIG_MAGIC_SYSRQ",
        expected_value="n",
        severity=Severity.MEDIUM,
        category="Debug Features",
        description="Disable SysRq magic key (can reboot/crash system)",
        remediation="Disable CONFIG_MAGIC_SYSRQ or set kernel.sysrq=0",
    ),
    # === Network Security ===
    ConfigCheck(
        name="CONFIG_SYN_COOKIES",
        expected_value="y",
        severity=Severity.HIGH,
        category="Network Security",
        description="Enable SYN cookie protection",
        remediation="Enable CONFIG_SYN_COOKIES=y",
    ),
    ConfigCheck(
        name="CONFIG_STRICT_DEVMEM",
        expected_value="y",
        severity=Severity.HIGH,
        category="Hardware Access",
        description="Restrict access to /dev/mem",
        remediation="Enable CONFIG_STRICT_DEVMEM=y",
    ),
    ConfigCheck(
        name="CONFIG_IO_STRICT_DEVMEM",
        expected_value="y",
        severity=Severity.MEDIUM,
        category="Hardware Access",
        description="Strict /dev/mem access control",
        remediation="Enable CONFIG_IO_STRICT_DEVMEM=y",
    ),
    ConfigCheck(
        name="CONFIG_DEVMEM",
        expected_value="n",
        severity=Severity.HIGH,
        category="Hardware Access",
        description="Completely disable /dev/mem (most secure)",
        remediation="Disable CONFIG_DEVMEM if not needed",
    ),
    # === Legacy/Unused Features ===
    ConfigCheck(
        name="CONFIG_LEGACY_PTYS",
        expected_value="n",
        severity=Severity.LOW,
        category="Legacy Features",
        description="Disable legacy PTYs",
        remediation="Disable CONFIG_LEGACY_PTYS",
    ),
    ConfigCheck(
        name="CONFIG_COMPAT_BRK",
        expected_value="n",
        severity=Severity.LOW,
        category="Legacy Features",
        description="Disable compatibility brk()",
        remediation="Disable CONFIG_COMPAT_BRK",
    ),
]
