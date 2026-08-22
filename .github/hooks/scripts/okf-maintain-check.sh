#!/usr/bin/env bash
# agentStop hook: forces one extra turn to run "/okf maintain" whenever the
# turn that just ended left new, uncommitted application-code changes behind
# (i.e. anything outside .okf/). This keeps the .okf/ knowledge bundle from
# drifting away from the codebase without requiring a human to remember to
# ask for a maintain pass.
#
# Anti-loop guards:
#   1. If this turn was already forced to continue by this same hook
#      (`stop_hook_active`), do nothing — never force twice in a row.
#   2. A signature of the current non-.okf diff is stored in the local
#      .git directory. The hook only fires again once that signature
#      changes, so a maintain pass that only touches .okf/ (as it should)
#      never re-triggers itself.
set -euo pipefail

input="$(cat)"

stop_hook_active="$(printf '%s' "$input" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
print("true" if data.get("stop_hook_active") else "false")
' 2>/dev/null || echo "false")"

if [ "$stop_hook_active" = "true" ]; then
  exit 0
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$repo_root" ]; then
  exit 0
fi

if [ ! -d "$repo_root/.okf" ]; then
  # No OKF bundle in this repository — nothing to maintain.
  exit 0
fi

git_dir="$(git -C "$repo_root" rev-parse --git-dir 2>/dev/null || true)"
if [ -z "$git_dir" ]; then
  exit 0
fi
case "$git_dir" in
  /*) : ;;
  *) git_dir="$repo_root/$git_dir" ;;
esac
state_file="$git_dir/copilot-okf-last-signature"

signature="$(
  {
    git -C "$repo_root" diff -- . ':(exclude).okf'
    git -C "$repo_root" diff --cached -- . ':(exclude).okf'
    git -C "$repo_root" status --porcelain -- . ':(exclude).okf'
  } | sha256sum | cut -d' ' -f1
)"

empty_signature="$(printf '' | sha256sum | cut -d' ' -f1)"

previous_signature=""
if [ -f "$state_file" ]; then
  previous_signature="$(cat "$state_file")"
fi

if [ "$signature" = "$empty_signature" ]; then
  # No uncommitted application-code changes right now — nothing to sync.
  printf '%s' "$signature" > "$state_file"
  exit 0
fi

if [ "$signature" = "$previous_signature" ]; then
  # Already prompted for this exact set of changes.
  exit 0
fi

printf '%s' "$signature" > "$state_file"

python3 -c '
import json
print(json.dumps({
    "decision": "block",
    "reason": (
        "New uncommitted application-code changes were detected outside "
        ".okf/. Before finishing, invoke the okf skill maintain playbook "
        "(/okf maintain) to sync the .okf/ knowledge bundle with these "
        "changes, then stop."
    ),
}))
'
