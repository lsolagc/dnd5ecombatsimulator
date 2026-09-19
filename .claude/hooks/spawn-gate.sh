#!/usr/bin/env bash
# spawn-gate.sh (PreToolUse, matcher Agent)
#
# Human approval before the build: spawning task-build asks the user (permissionDecision
# "ask", confirmed to reach the user even in defaultMode auto) showing the specification's
# "Decisões para Veto". The briefing must contain that section (write "Nenhuma" if there
# are none), otherwise the spawn is denied so the specification cannot be skipped.
# Iteration rounds resume the same agent through SendMessage, so they are not asked again.
#
# This guarantees the decisions were put in front of the user, not that the spec classified
# them honestly. Escape hatch: launch Claude Code with CLAUDE_GATE_OFF=1.
set -u
INPUT="$(cat)"
[ "${CLAUDE_GATE_OFF:-}" = "1" ] && exit 0

[ "$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // ""')" = "task-build" ] || exit 0

PROMPT="$(printf '%s' "$INPUT" | jq -r '.tool_input.prompt // ""')"
HEADING_RE='Decis(õ|o)es para Veto'

emit() {
  jq -n --arg decision "$1" --arg reason "$2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $decision, permissionDecisionReason: $reason}}'
  exit 0
}

if ! printf '%s\n' "$PROMPT" | grep -Eiq "$HEADING_RE"; then
  emit deny "Spawn de task-build negado: o briefing precisa conter a seção \"Decisões para Veto\" (saída da fase de especificação; escreva \"Nenhuma\" se não houver decisões). Ela é mostrada ao usuário para aprovação antes do build."
fi

START="$(printf '%s\n' "$PROMPT" | grep -nEi "$HEADING_RE" | head -1 | cut -d: -f1)"
SECTION="$(printf '%s\n' "$PROMPT" | tail -n +"$START" | awk 'NR==1 {print; next} /^#/ {exit} {print}' | head -40)"

emit ask "Aprovação humana antes do build (task-build). Decisões para Veto declaradas pela especificação:

$SECTION

Aprove somente se concorda com estas decisões; negue para voltar à especificação."
