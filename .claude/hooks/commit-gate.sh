#!/usr/bin/env bash
# commit-gate.sh (PreToolUse, matcher Bash)
#
# No evidence, no commit: runs the verification if the current code state has none, and
# denies the commit unless it is green. Only ever denies; never rewrites the command
# (rtk and caveman already do that on Bash and parallel rewrites are not deterministic).
#
# It runs on every Bash call and decides by itself whether the command is a commit. The
# hook-level `if: "Bash(git commit *)"` is deliberately not used: it misses `git -C dir
# commit` / `git -c k=v commit`, and Claude Code runs the hook anyway when the command
# cannot be parsed statically (e.g. `$VAR args`), which must not deny unrelated commands.
#
# Known bypasses, accepted: aliases, `git commit-tree`, `--no-verify`. The regex scans the
# whole command text, so `bash -c "git commit"` is caught, and so is a command that merely
# mentions `git commit` (it just triggers a verification). Escape hatch: launch Claude
# Code with CLAUDE_GATE_OFF=1.
set -u
INPUT="$(cat)"
[ "${CLAUDE_GATE_OFF:-}" = "1" ] && exit 0

COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"
COMMIT_RE='(^|[^[:alnum:]_.-])git([[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+|--?[[:alnum:]-]+(=[^[:space:]]+)?))*[[:space:]]+commit([[:space:]]|$)'
printf '%s' "$COMMAND" | grep -Eq "$COMMIT_RE" || exit 0

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SIG="$(signature)"
[ -f "$GATE_STATE/green/$SIG" ] && exit 0

verify_locked "$SIG"
[ "$GATE_RESULT" = "green" ] && exit 0

deny() {
  jq -n --arg reason "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
}

if [ "$GATE_RESULT" = "infra" ]; then
  deny "commit bloqueado: não foi possível verificar o código ($GATE_SUMMARY). Sem evidência, sem commit. Rode a suíte manualmente ou peça ao usuário para liberar (CLAUDE_GATE_OFF=1)."
fi
deny "commit bloqueado: a verificação está VERMELHA ($GATE_SUMMARY). Corrija e tente de novo. Saída (fim): $(printf '%s' "$GATE_TAIL" | tail -25)"
