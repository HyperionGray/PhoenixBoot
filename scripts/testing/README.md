# Testing Scripts

Scripts for testing PhoenixBoot functionality using QEMU and other methods.

## QEMU Test Scripts

- `qemu-test.sh` - Basic QEMU boot test
- `qemu-test-cloudinit.sh` - Test cloud-init integration
- `qemu-test-secure-positive.sh` - SecureBoot enabled test
- `qemu-test-secure-strict.sh` - SecureBoot strict mode test
- `qemu-test-secure-negative-attest.sh` - Test corruption detection
- `qemu-test-secure-negative-attest-nosudo.sh` - Corruption detection (no sudo)
- `qemu-test-uuefi.sh` - Test UUEFI diagnostic tool
- `test-qemu-fixed.sh` - Fixed QEMU test configuration

## End-to-End Tests

- `run-e2e-tests.sh` - Run all end-to-end tests
- `run-staging-tests.sh` - Run staging tests

## Other Tests

- `test_kvm_install.sh` - Test KVM installation
- `test-uuefi-simple.sh` - Simple UUEFI test
- `iso-run.sh` - Run ISO tests

## Usage

```bash
# Run individual test
./scripts/testing/qemu-test.sh

# Or via task runner
./pf.py test-qemu
./pf.py test-qemu-cloudinit
./pf.py test-e2e-all
./pf.py test-staging
```
