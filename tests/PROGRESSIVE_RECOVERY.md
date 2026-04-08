# Progressive Recovery Tests

This suite covers smoke validation for the progressive recovery flow.

Targets (invoked via `./pf.py <task>` or individually):
- test-progressive-smoke: Ensures level1 (scan) and level2 (ESP build/verify) execute without modifying the host.
- test-progressive-planfile: Verifies that running `./pf.py nuke-progressive-dry-run` writes a well-formed planfile.
- test-esp-validation: Reuses existing ESP verification.

Manual steps (for now):
1) Smoke
   ./pf.py nuke-level1-scan
   ISO_PATH=/path/to/PhoenixGuard-Nuclear-Recovery.iso ./pf.py nuke-level2-esp

2) Planfile
   ./pf.py nuke-progressive-dry-run
   ls plans/phoenix_progressive_*.json
   bash tests/progressive_planfile_check.sh

3) ESP validation
   ./pf.py verify-esp-robust

Future work: add additional assertions for per-level step command structures.
