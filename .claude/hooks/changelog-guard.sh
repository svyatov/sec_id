#!/usr/bin/env bash
# PreToolUse(Bash): block feat/fix commits that touch lib/ without updating CHANGELOG.md.
# Scoped to feat/fix because those are the version-bumping types (see CLAUDE.md Commit table) that
# require a changelog entry. Escape hatch: use a non-bumping type (refactor/chore/docs/...) instead.
set -euo pipefail

# Matches a Conventional Commit feat/fix subject: optional (scope), optional !, then ':'.
is_enforced_commit() {
  local c=$1
  [[ $c == *"git commit"* ]] || return 1
  grep -Eq '(feat|fix)(\([^)]*\))?!?:' <<<"$c"
}

if [[ ${1:-} == --self-check ]]; then
  is_enforced_commit 'git commit -am "feat: add WKN"'        || { echo FAIL feat; exit 1; }
  is_enforced_commit 'git commit -m "fix(cusip): pad input"' || { echo FAIL fix-scope; exit 1; }
  is_enforced_commit 'git commit -am "feat!: rename"'        || { echo FAIL bang; exit 1; }
  ! is_enforced_commit 'git commit -am "refactor: tidy"'     || { echo FAIL refactor; exit 1; }
  ! is_enforced_commit 'git commit -am "feat add no colon"'  || { echo FAIL no-colon; exit 1; }
  ! is_enforced_commit 'git status'                          || { echo FAIL non-commit; exit 1; }
  echo "self-check OK"; exit 0
fi

cmd=$(jq -r '.tool_input.command // empty')
is_enforced_commit "$cmd" || exit 0

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root"

# Files this commit will include: tracked-modified (covers `commit -a`) plus staged.
changed=$(git diff HEAD --name-only; git diff --cached --name-only)
grep -Eq '^lib/.*\.rb$' <<<"$changed" || exit 0   # no lib change → nothing to enforce
grep -qx 'CHANGELOG.md'  <<<"$changed" && exit 0   # changelog already touched → fine

{
  echo "Pre-commit checklist: this feat/fix changes lib/ but CHANGELOG.md is untouched."
  echo "Add an entry under [Unreleased] (and check README / CLAUDE.md / gemspec description), then retry."
  echo "If the change is genuinely not user-facing, use a non-bumping type (refactor/chore/docs/...) instead."
} >&2
exit 2
