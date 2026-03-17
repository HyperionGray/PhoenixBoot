# PhoenixBoot CLI and TUI Testing

This directory contains comprehensive test suites for the PhoenixBoot command-line interface (CLI) and terminal user interface (TUI).

## Test Scripts

### Individual Test Suites

1. **test-phoenixboot-cli.sh** - Tests the `phoenixboot` CLI wrapper
   - Validates phoenixboot file exists and is executable
   - Tests pb symlink
   - Tests common commands (help, status, list)
   - Verifies root directory detection
   - Tests error handling

2. **test-phoenixboot-tui.sh** - Tests the PhoenixBoot TUI launcher
   - Validates phoenixboot-tui.sh file and permissions
   - Checks TUI app Python file exists
   - Validates bash and Python syntax
   - Verifies dependencies are documented
   - Tests root directory detection logic

3. **test-pf-tasks.sh** - Validates pf.py task definitions
   - Checks all .pf files exist
   - Validates pf.py is executable
   - Tests pf.py list command
   - Verifies essential tasks are defined
   - Checks task descriptions and shell commands

### Master Test Runner

**test-all-cli-tui.sh** - Runs all test suites in sequence
- Executes all three test suites
- Writes per-suite logs to `out/test-results/cli-tui/`
- Supports suite filtering for faster local/CI runs
- Can emit machine-readable JSON summaries
- Provides comprehensive summary with per-suite duration
- Returns exit code 0 only if all tests pass

## Running Tests

### Run All Tests
```bash
# From PhoenixBoot root directory
./scripts/testing/test-all-cli-tui.sh
```

### Run Only Selected Suites
```bash
# Run only CLI and PF suite
./scripts/testing/test-all-cli-tui.sh --suite cli,pf

# Equivalent with repeated flags
./scripts/testing/test-all-cli-tui.sh --suite cli --suite pf
```

### Generate JSON Report (CI-friendly)
```bash
./scripts/testing/test-all-cli-tui.sh \
  --json-report out/test-results/cli-tui/summary.json
```

### Stop Early on Failure
```bash
./scripts/testing/test-all-cli-tui.sh --stop-on-fail
```

### Run Individual Test Suites
```bash
# Test CLI only
./scripts/testing/test-phoenixboot-cli.sh

# Test TUI only
./scripts/testing/test-phoenixboot-tui.sh

# Test pf.py tasks only
./scripts/testing/test-pf-tasks.sh
```

### Run via pf.py Tasks
```bash
# Using phoenixboot wrapper
./phoenixboot test-cli-tui-all

# Or individual tests
./phoenixboot test-cli
./phoenixboot test-tui
./phoenixboot test-pf
```

### Environment Variable Controls
```bash
# Select suites via environment variable
PB_TEST_SUITES=cli,tui ./scripts/testing/test-all-cli-tui.sh

# Write JSON report via environment variable
PB_TEST_JSON_REPORT=out/test-results/cli-tui/summary.json \
  ./scripts/testing/test-all-cli-tui.sh

# Stop on first failure via environment variable
PB_TEST_STOP_ON_FAIL=1 ./scripts/testing/test-all-cli-tui.sh
```

## Test Results

Tests use color-coded output:
- ✓ **Green** - Test passed
- ✗ **Red** - Test failed
- ⊘ **Yellow** - Test skipped (usually due to missing optional dependencies)

## Expected Behavior

Most tests should pass even without optional dependencies like the `fabric` Python module. Tests that require external dependencies will be skipped with a clear message.

### Known Skipped Tests
- `pf.py list` command - Requires fabric module (Python dependency)
- Some advanced pf.py task execution tests

## Integration with CI/CD

These tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Test PhoenixBoot CLI/TUI
  run: |
    cd /path/to/PhoenixBoot
    ./scripts/testing/test-all-cli-tui.sh
```

## Test Coverage

The test suites cover:
- ✅ File existence and permissions
- ✅ Bash script syntax validation
- ✅ Python script syntax validation
- ✅ Basic command execution
- ✅ Symlink validation
- ✅ Root directory detection
- ✅ Task definitions and descriptions
- ✅ Error handling

## Troubleshooting

### All tests fail
- Ensure you're running from the PhoenixBoot root directory
- Check that phoenixboot and pb files exist
- Verify file permissions are correct

### Specific test fails
- Read the error message carefully
- Tests include descriptive output about what failed
- Check that required files haven't been moved or deleted

### Tests timeout
- Some tests may take longer on slower systems
- Consider running individual test suites instead of the master runner

## Adding New Tests

To add new tests:

1. Add test functions to the appropriate test script
2. Follow the existing pattern:
   ```bash
   echo "[TEST N] Description..."
   if condition; then
       pass "Success message"
   else
       fail "Failure message"
   fi
   ```
3. Update the test counter
4. Test your changes

## Dependencies

### Required
- bash
- python3
- Standard Unix tools (grep, find, etc.)

### Optional
- fabric (Python module) - For full pf.py functionality
- textual (Python module) - For TUI functionality

## Exit Codes

- **0** - All tests passed
- **1** - One or more tests failed

## Artifacts

When running `test-all-cli-tui.sh`, artifacts are stored in:

- `out/test-results/cli-tui/cli.log`
- `out/test-results/cli-tui/tui.log`
- `out/test-results/cli-tui/pf.log`
- Optional summary JSON path passed via `--json-report`

## Maintenance

These tests should be run:
- Before committing changes to CLI/TUI code
- As part of CI/CD pipeline
- After updating dependencies
- When adding new pf.py tasks
