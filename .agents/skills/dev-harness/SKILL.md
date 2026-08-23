---
name: dev-harness
description: Orquestra o loop completo de desenvolvimento deste projeto (especificação, build, revisão adversarial, fitness) para uma tarefa, iterando até passar ou esgotar o orçamento. Use quando o usuário pedir para "rodar o harness", entregar uma tarefa ponta a ponta neste repo, ou pedir um loop spec-build-review-teste.
---

# Harness de Desenvolvimento

Pega uma demanda (qualquer nível de detalhe) e entrega implementada, revisada e validada contra
critério de aceite verificável, iterando até passar ou esgotar o orçamento de iterações.

## Fases

### 1. Especificação
Siga o procedimento de `.agents/skills/task-specification/SKILL.md`: ler README mínimo primeiro,
perguntar só o essencial não documentado, consolidar Demanda, Escopo (dentro/fora), Decomposição e
**Critérios de Aceite verificáveis**. Não implemente nesta fase.

Se a demanda decompuser em subtarefas, rode as fases 2-4 para cada uma, na ordem de dependência
declarada.

### 2. Build
Spawn subagent `task-build` (Agent tool) com a demanda consolidada, escopo e critérios de aceite.
Na primeira iteração ele implementa do zero; nas seguintes, passe também o feedback da rodada
anterior (achados bloqueantes da revisão + falhas de teste) para ele resolver antes de qualquer coisa.

### 3. Revisão adversarial
Spawn subagent **fresco** (sem contexto da fase 2 — evita revisar as próprias justificativas do
builder) seguindo `.agents/skills/adversarial-review/SKILL.md`, contestando especificamente se os
**Critérios de Aceite** da fase 1 foram atendidos — não é revisão de qualidade de código genérica.
Saída: conclusão inicial, hipóteses alternativas, evidências, limites, recomendação final marcada
como bloqueante ou não-bloqueante.

### 4. Fitness
Piso, sempre: `bundle exec rubocop` + `bin/rails test` (ao menos os arquivos/diretórios tocados).

Some o(s) critério(s) específico(s) do tipo de tarefa:
- Efeito/habilidade de combate → `.agents/skills/combat-mechanics-testing/SKILL.md`.
- Mudança perto de `EncounterService` → `.agents/skills/safe-change-sensitive-area/SKILL.md`
  (contratos declarados não podem quebrar).
- Balanceamento → `.agents/skills/canonical-combat-scenario/SKILL.md` +
  `.agents/skills/simulation-evaluation-metrics/SKILL.md` (limiar aprovado/reprovado explícito).
- UI/frontend → `.agents/skills/ui-system-test/SKILL.md` (teste de sistema + screenshot revisado).
- Qualquer RNG envolvido → `.agents/skills/reproducible-rolls/SKILL.md` (seed controlada).

Fitness atingida = piso verde + critério(s) específico(s) verde(s) + review não-bloqueante.

### 5. Iteração
Fitness falhou ou review bloqueou → volte à fase 2 com o feedback consolidado, até `max_iteracoes`
(padrão 3). Esgotado o orçamento sem sucesso: pare e reporte o estado real ao usuário — nunca declare
sucesso a fórceps.

## Ao concluir
Se a mudança afetou comportamento de combate, feche com
`.agents/skills/mechanics-impact-report/SKILL.md`. Caso contrário, resumo curto: o que mudou, o que
passou (testes/revisão), quais critérios de aceite foram atendidos.

## Argumentos
- Demanda (texto livre, qualquer nível de detalhe).
- `max_iteracoes` (opcional, padrão 3).
