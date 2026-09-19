#!/usr/bin/env bash
# session-context.sh (SessionStart, matcher compact|resume)
#
# After a compaction or resume the model forgets the gates and whether the current code was
# verified. stdout of SessionStart hooks is added to Claude's context.
set -u
cat > /dev/null
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SIG="$(signature)"
echo "Garantias por hooks ativas neste repositório (ver AGENTS.md):"
echo "- Encerrar o turno com código alterado e não verificado roda rubocop + bin/rails test de verdade; vermelho bloqueia uma vez."
echo "- git commit é negado sem verificação verde. Spawn de task-build pede aprovação humana das \"Decisões para Veto\"."
echo "- Revisões devem usar o agente task-review: ele precisa executar a suíte e sabotar invariantes (ou declarar \"Sem invariantes: <razão>\")."
echo "- Testes de banco: as credenciais só existem em shell interativa; use bash -ic 'bin/rails test'."
if [ -f "$GATE_STATE/green/$SIG" ]; then
  echo "Estado atual do código: VERIFICADO ($(jq -r '.summary // "sem resumo"' "$GATE_STATE/evidence.json" 2>/dev/null))."
elif [ -f "$GATE_STATE/red/$SIG" ]; then
  echo "Estado atual do código: VERMELHO (a verificação já falhou para este estado)."
else
  echo "Estado atual do código: NÃO VERIFICADO desde a última alteração."
fi
exit 0
