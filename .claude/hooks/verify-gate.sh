#!/usr/bin/env bash
# verify-gate.sh <baseline|verify>
#
# baseline (UserPromptSubmit): records the code signature at the start of the turn.
# verify   (Stop, SubagentStop): if code changed during the turn and that state was never
#          verified, runs rubocop + the test suite. Green -> allow and record evidence.
#          Red -> block once per signature (exit 2, output tail on stderr), so the agent
#          fixes it, without ever looping. Infrastructure failure -> allow, loudly.
#
# Escape hatch: launch Claude Code with CLAUDE_GATE_OFF=1.
set -u
MODE="${1:-verify}"
INPUT="$(cat)"
[ "${CLAUDE_GATE_OFF:-}" = "1" ] && exit 0

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // "none"')"
BASELINE_FILE="$GATE_STATE/baseline.$SESSION_ID"
SIG="$(signature)"

say() { jq -n --arg m "$1" '{systemMessage: $m}'; }

if [ "$MODE" = "baseline" ]; then
  printf '%s' "$SIG" > "$BASELINE_FILE"
  exit 0
fi

[ -f "$GATE_STATE/green/$SIG" ] && exit 0
[ -f "$BASELINE_FILE" ] && [ "$(cat "$BASELINE_FILE")" = "$SIG" ] && exit 0

verify_locked "$SIG"

case "$GATE_RESULT" in
  green)
    say "verify-gate: verificado de verdade ($GATE_COMMANDS): $GATE_SUMMARY"
    exit 0
    ;;
  infra)
    say "verify-gate: NÃO FOI POSSÍVEL VERIFICAR este código ($GATE_SUMMARY). Nada foi bloqueado, mas o estado atual não tem evidência. Rode 'bin/rails test' você mesmo."
    exit 0
    ;;
  red)
    if [ -f "$GATE_STATE/red/$SIG" ]; then
      say "verify-gate: verificação continua VERMELHA ($GATE_SUMMARY), mas já bloqueou uma vez para este estado; liberando para não entrar em loop."
      exit 0
    fi
    : > "$GATE_STATE/red/$SIG"
    {
      echo "verify-gate: verificação VERMELHA ($GATE_SUMMARY). Corrija antes de encerrar. Saída (fim):"
      printf '%s\n' "$GATE_TAIL"
    } >&2
    exit 2
    ;;
esac
exit 0
