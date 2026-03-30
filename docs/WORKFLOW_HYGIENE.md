# Workflow Hygiene

This project keeps `.github/workflows/` intentionally clean to reduce CI drift,
accidental duplicate workflows, and stale template artifacts.

## What is validated

`scripts/maintenance/validate-workflow-hygiene.py` checks:

- Hidden files in `.github/workflows/` (for example `.bish-*` leftovers)
- Non-`.yml`/`.yaml` files in the workflows directory
- Duplicate workflow basenames (`foo.yml` + `foo.yaml`)
- Backup/template workflow filenames
- Placeholder workflow markers
- Missing top-level `name:` or `on:` keys

## Run locally

```bash
python3 scripts/maintenance/validate-workflow-hygiene.py
```

Or through pf task runner:

```bash
./pf.py maint-workflow-hygiene
```

## CI enforcement

Workflow: `.github/workflows/workflow-hygiene.yml`

It runs on:
- Pull requests touching `.github/workflows/**` or the validator script
- Pushes to `main`/`master` touching the same paths
- Manual dispatch

## Why this exists

The repository has heavy automation usage and many workflow files. This guardrail
prevents accidental duplication and stale files from quietly changing automation
behavior.
