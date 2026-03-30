# Progressive Recovery Tests

This suite covers smoke validation for the progressive recovery flow.

Targets (invoked via pf tasks or individually):
- test-progressive-smoke: Ensures detection and ESP build/verify steps execute without modifying the host.
- test-progressive-planfile: Verifies progressive recovery command flow and output handling.
- test-esp-validation: Reuses existing ESP verification.

Manual steps (for now):
1) Smoke
   ./pf.py secure-env
   ./pf.py workflow-cd-prepare

2) Planfile
   python3 scripts/recovery/phoenix_progressive.py
   # Follow prompts and verify output/log behavior for selected level(s)

3) ESP validation
   ./pf.py verify-esp-robust

Future work: add a small shell harness to parse planfile and assert required fields without jq dependency.
