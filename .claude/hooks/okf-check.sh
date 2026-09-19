#!/usr/bin/env bash
# okf-check.sh: Claude Code port of .github/hooks/scripts/okf-maintain-check.sh (Copilot).
# Called by stop-dispatch.sh, not registered on its own, so it never races the verify gate.
#
# When a turn leaves uncommitted code changes (GATE_PATHS, see lib.sh) whose content was not
# yet announced, asks for one extra turn to sync the .okf/ bundle. Anti-loop: never fires
# under stop_hook_active, and only again once the code signature changes. Uses its own state
# file (the Copilot script keeps .git/copilot-okf-last-signature).
set -u
INPUT="$(cat)"
[ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
[ -d "$GATE_ROOT/.okf" ] || exit 0

STATE_FILE="$GATE_STATE/okf-last-signature"
if [ -z "$(git status --porcelain -- "${GATE_PATHS[@]}" 2>/dev/null)" ]; then
  : > "$STATE_FILE"
  exit 0
fi

SIG="$(signature)"
[ "$SIG" = "$(cat "$STATE_FILE" 2>/dev/null)" ] && exit 0
printf '%s' "$SIG" > "$STATE_FILE"

jq -n '{decision: "block", reason: "New uncommitted application-code changes were detected outside .okf/. Before finishing, invoke the okf skill maintain playbook (/okf maintain) to sync the .okf/ knowledge bundle with these changes, then stop."}'
exit 0
