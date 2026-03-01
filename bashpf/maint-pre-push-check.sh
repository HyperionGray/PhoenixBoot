#!/usr/bin/env bash
# Run the size guard check locally (no push)
bash -lc 'scripts/git-hooks/pre-push <<EOF
$(git rev-parse HEAD) 0000000000000000000000000000000000000000 refs/heads/main
EOF'
