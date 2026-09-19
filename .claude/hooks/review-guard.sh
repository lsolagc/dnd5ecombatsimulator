#!/usr/bin/env bash
# review-guard.sh (PreToolUse, matcher Bash)
#
# The reviewer sabotages code to prove the tests catch it, then must restore it by hand.
# git checkout/restore/stash/reset/clean would also wipe the builder's uncommitted work,
# so they are denied for task-review only. Every other agent is untouched.
set -u
INPUT="$(cat)"
[ "${CLAUDE_GATE_OFF:-}" = "1" ] && exit 0

[ "$(printf '%s' "$INPUT" | jq -r '.agent_type // ""')" = "task-review" ] || exit 0

COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"
GIT_DESTRUCTIVE_RE='(^|[^[:alnum:]_.-])git([[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+|--?[[:alnum:]-]+(=[^[:space:]]+)?))*[[:space:]]+(checkout|restore|stash|reset|clean|switch)([[:space:]]|$)'
printf '%s' "$COMMAND" | grep -Eq "$GIT_DESTRUCTIVE_RE" || exit 0

jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "task-review não pode usar git checkout/restore/stash/reset/clean/switch: eles apagariam o trabalho não commitado do builder. Faça a sabotagem com Edit e reverta com Edit (ou restaure de uma cópia em /tmp), depois confirme com git diff que o estado voltou ao original."}}'
exit 0
