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

Se a demanda decompuser em subtarefas, rode as fases 1-4 para cada uma, na ordem de dependência
declarada: a especificação é refeita por subtarefa, não uma vez só para a demanda inteira.

Não avance para a fase 2 enquanto o Encaminhamento da especificação for "Aguardando resposta do
usuário". As "Decisões para Veto" e as invariantes da especificação vão no briefing do build.

Um hook garante isso: o spawn do `task-build` é **negado** se o briefing não tiver a seção
"Decisões para Veto" (escreva "Nenhuma" se não houver), e, com a seção, o usuário é **consultado**
(aprovação humana real) antes do build começar. Recusar volta à especificação.

### 2. Build
Spawn subagent `task-build` (Agent tool) com a demanda consolidada, escopo e critérios de aceite.
Na primeira iteração ele implementa do zero; nas seguintes, passe também o feedback da rodada
anterior (achados bloqueantes da revisão + falhas de teste) para ele resolver antes de qualquer coisa.

### 3. Revisão adversarial
Spawn o subagent **fresco** `task-review` (sem contexto da fase 2 — evita revisar as próprias
justificativas do builder), que segue `.agents/skills/adversarial-review/SKILL.md` e contesta
especificamente se os **Critérios de Aceite** da fase 1 foram atendidos — não é revisão de
qualidade de código genérica. Passe a ele os Critérios de Aceite e as invariantes da especificação.

Saída: conclusão inicial, hipóteses alternativas, evidências, limites, recomendação final marcada
como bloqueante ou não-bloqueante.

Se a especificação listou invariantes, o revisor executa (não só lê) e sabota cada uma, para
confirmar que algum teste falha. Revisão apenas por leitura de código não conta como evidência.

Um hook valida o revisor ao terminar e o impede de encerrar até que: o relatório tenha as cinco
seções e o veredito; o transcript mostre execução real da suíte; haja sabotagem comprovada de
`app/` ou `lib/` (execução verde, edição, execução vermelha) ou a linha "Sem invariantes: <razão>";
e o código tenha voltado ao estado original. Nesse agente, `git checkout/restore/stash/reset/clean`
são negados, porque apagariam o trabalho não commitado do builder.

### 4. Fitness
Piso, sempre: `bundle exec rubocop` + `bin/rails test` (ao menos os arquivos/diretórios tocados).

Rode de verdade e reporte a evidência (comando e números). Nunca dê como verde por leitura de
código. Se o ambiente não permitir executar, pare e diga ao usuário quem vai rodar.

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
