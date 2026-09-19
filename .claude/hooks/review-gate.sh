#!/usr/bin/env bash
# review-gate.sh (SubagentStop, matcher task-review)
#
# A review only counts if the reviewer actually executed things. Blocks the reviewer (exit
# 2, so it keeps working) until:
#   1. the report has the five adversarial-review sections and a BLOQUEANTE/NÃO-BLOQUEANTE
#      verdict;
#   2. the transcript shows a real test run (a tool result carrying "N runs, M assertions,
#      F failures, E errors"), not just a command that mentions it;
#   3. unless the report has an explicit "Sem invariantes: <reason>" line, the transcript
#      shows a sabotage: a green run, then an edit under app/ or lib/, then a run with
#      failures or errors;
#   4. the code signature equals the one recorded when the reviewer started, i.e. the
#      sabotage was reverted.
# Blocks at most twice per reviewer, then lets it go with a warning (no loops). If the
# transcript cannot be read, it warns and allows: the gate must not invent failures.
set -u
INPUT="$(cat)"
[ "${CLAUDE_GATE_OFF:-}" = "1" ] && exit 0

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty')"
TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.agent_transcript_path // empty')"
REPORT="$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""')"

say() { jq -n --arg m "$1" '{systemMessage: $m}'; }

if [ -z "$AGENT_ID" ] || [ ! -r "$TRANSCRIPT" ]; then
  say "review-gate: não foi possível ler o transcript do revisor; a revisão NÃO foi validada."
  exit 0
fi

mkdir -p "$GATE_STATE/review"
BLOCKS_FILE="$GATE_STATE/review/$AGENT_ID.blocks"
BLOCKS="$(cat "$BLOCKS_FILE" 2>/dev/null || echo 0)"

problems=()

# 1. Report structure and verdict.
for section in 'Conclus' 'Hip[oó]teses' 'Evid[eê]ncias' 'Limites' 'Recomenda'; do
  printf '%s' "$REPORT" | grep -Eiq "$section" || problems+=("o relatório não tem a seção \"$section...\" (Conclusão inicial, Hipóteses alternativas, Evidências por hipótese, Limites e riscos, Recomendação final)")
done
printf '%s' "$REPORT" | grep -Eiq 'BLOQUEANTE' || problems+=("o relatório não traz o veredito BLOQUEANTE ou NÃO-BLOQUEANTE")

# 2 and 3. Executed runs and sabotage, read from the transcript.
EVENTS="$(jq -c -s '
  [ .[] | select(.message.content | type == "array") | .message.content[] ] as $items
  | ( [ $items[] | select(.type == "tool_result")
        | { key: .tool_use_id,
            value: (if (.content | type) == "string" then .content else ([.content[]? | .text? // empty] | join("\n")) end) } ]
      | from_entries ) as $results
  | [ $items[] | select(.type == "tool_use")
      | if .name == "Bash" and ((.input.command // "") | test("rails test|rake test")) then
          ( [ ($results[.id] // "") | scan("([0-9]+) runs?, [0-9]+ assertions?, ([0-9]+) failures?, ([0-9]+) errors?") ] | last ) as $c
          | { kind: "run", counted: ($c != null), red: (if $c then ((($c[1] | tonumber) + ($c[2] | tonumber)) > 0) else null end) }
        elif (.name == "Edit" or .name == "Write" or .name == "MultiEdit") and ((.input.file_path // "") | test("/(app|lib)/")) then
          { kind: "edit" }
        elif .name == "Bash" and ((.input.command // "") | test("sed[[:space:]]+-i[^|;&]*(app|lib)/")) then
          { kind: "edit" }
        else empty end ]
' "$TRANSCRIPT" 2>/dev/null)"

if [ -z "$EVENTS" ]; then
  say "review-gate: transcript do revisor ilegível; a revisão NÃO foi validada."
  exit 0
fi

counted_runs="$(printf '%s' "$EVENTS" | jq '[.[] | select(.kind == "run" and .counted)] | length')"
[ "$counted_runs" -ge 1 ] || problems+=("o transcript não mostra nenhuma execução real da suíte (saída com \"N runs, M assertions, F failures, E errors\"); rode bash -ic 'bin/rails test' e mostre o resultado")

if ! printf '%s' "$REPORT" | grep -Eiq 'Sem invariantes:[[:space:]]*[^[:space:]]'; then
  sabotaged="$(printf '%s' "$EVENTS" | jq '
    . as $e
    | any(range(0; $e | length); . as $j
        | $e[$j].kind == "edit"
          and any(range(0; $j); $e[.].kind == "run" and $e[.].counted and ($e[.].red == false))
          and any(range($j + 1; $e | length); $e[.].kind == "run" and $e[.].counted and ($e[.].red == true)))')"
  [ "$sabotaged" = "true" ] || problems+=("não há sabotagem comprovada no transcript: é preciso uma execução verde, depois uma edição em app/ ou lib/, depois uma execução vermelha. Se a especificação não listou invariantes, escreva no relatório a linha \"Sem invariantes: <razão>\"")
fi

# 4. Tree restored.
START_SIG="$(cat "$GATE_STATE/review/$AGENT_ID.start-sig" 2>/dev/null || true)"
if [ -n "$START_SIG" ] && [ "$(signature)" != "$START_SIG" ]; then
  problems+=("o código não voltou ao estado de antes da revisão (a sabotagem não foi revertida); reverta com Edit e confira com git diff")
fi

if [ "${#problems[@]}" -eq 0 ]; then
  say "review-gate: revisão validada (execução real da suíte, sabotagem comprovada ou dispensada, árvore restaurada)."
  exit 0
fi

if [ "$BLOCKS" -ge 2 ]; then
  say "review-gate: a revisão continua incompleta após 2 bloqueios; liberando com aviso. Pendências: $(printf '%s; ' "${problems[@]}")"
  exit 0
fi

echo $((BLOCKS + 1)) > "$BLOCKS_FILE"
{
  echo "review-gate: revisão INCOMPLETA. Resolva antes de encerrar:"
  printf -- '- %s\n' "${problems[@]}"
} >&2
exit 2
