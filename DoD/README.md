# PhoenixBoot DoD Helpers

This directory groups PhoenixBoot helpers for teams working through DISA STIG-style hardening while still keeping security outcomes front and center.

## Commands

- `python3 DoD/disa_stig_helper.py info` - detect the local distro family and print compliance/security guidance
- `python3 DoD/disa_stig_helper.py check` - run the existing kernel hardening analyzer with distro-aware guidance
- `python3 DoD/disa_stig_helper.py generate-secure-config --output out/dod/secure_kernel.config` - generate a distro-aware hardened kernel config fragment

## CLI Tasks

- `./pf.py dod-info`
- `./pf.py dod-stig-check`
- `OUTPUT=out/dod/secure_kernel.config ./pf.py dod-secure-config`

The helper is intentionally distro-aware for both RHEL-like and Ubuntu/Debian-like systems so operators get guidance that better matches the platform they are actually deploying.
