#!/usr/bin/env bash
# stop-dispatch.sh (Stop): single entry point so the checks run in a fixed order instead of
# in parallel (parallel Stop hooks would let the OKF request fire while the gate is red).
#   1. verify-gate.sh verify: red blocks (exit 2) and nothing else runs;
#   2. okf-check.sh: asks for a /okf maintain turn when code changed and the gate is not red.
set -u
INPUT="$(cat)"
DIR="$(dirname "${BASH_SOURCE[0]}")"

GATE_OUT="$(printf '%s' "$INPUT" | "$DIR/verify-gate.sh" verify 2> >(cat >&2))"
GATE_RC=$?
if [ "$GATE_RC" -ne 0 ]; then
  [ -n "$GATE_OUT" ] && printf '%s\n' "$GATE_OUT"
  exit "$GATE_RC"
fi

OKF_OUT="$(printf '%s' "$INPUT" | "$DIR/okf-check.sh")"

if [ -n "$OKF_OUT" ]; then
  # Keep the gate's evidence message next to the OKF block so neither is lost.
  MSG="$(printf '%s' "$GATE_OUT" | jq -r '.systemMessage // empty' 2>/dev/null)"
  printf '%s' "$OKF_OUT" | jq -c --arg m "$MSG" 'if $m != "" then . + {systemMessage: $m} else . end'
  exit 0
fi

[ -n "$GATE_OUT" ] && printf '%s\n' "$GATE_OUT"
exit 0
