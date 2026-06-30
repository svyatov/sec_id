#!/usr/bin/env bash
# PostToolUse(Edit|Write): auto-correct edited Ruby files with RuboCop.
# Best-effort: never fails the tool call (exits 0 even if RuboCop is absent or reports unfixable offenses).
set -euo pipefail

file=$(jq -r '.tool_input.file_path // empty')
[[ $file == *.rb && -f $file ]] || exit 0

root=$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root"

# --force-exclusion honors .rubocop.yml excludes even when a single path is passed.
bundle exec rubocop -a --force-exclusion "$file" >/dev/null 2>&1 || true
exit 0
