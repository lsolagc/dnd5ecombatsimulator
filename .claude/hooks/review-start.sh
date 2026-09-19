#!/usr/bin/env bash
# review-start.sh (SubagentStart, matcher task-review)
#
# Records the code signature when a reviewer starts, so review-gate.sh can prove the tree
# was restored after the reviewer sabotaged it. Cannot block (SubagentStart never does).
set -u
INPUT="$(cat)"
[ "${CLAUDE_GATE_OFF:-}" = "1" ] && exit 0

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty')"
[ -n "$AGENT_ID" ] || exit 0
mkdir -p "$GATE_STATE/review"
signature > "$GATE_STATE/review/$AGENT_ID.start-sig"
exit 0
