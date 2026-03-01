#!/usr/bin/env bash
# Install pre-push size guard hook
mkdir -p .git/hooks && chmod 0755 .git/hooks
cp scripts/git-hooks/pre-push .git/hooks/pre-push && chmod 0755 .git/hooks/pre-push
