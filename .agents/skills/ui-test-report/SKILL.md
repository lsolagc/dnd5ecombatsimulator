---
name: ui-test-report
description: 'Gere um documento de QA manual para uma mudança de UI: prints do que foi construído + passo a passo para testar na mão. Use ao final de uma feature de UI, depois do teste de sistema (ui-system-test), como entregável para quem vai validar manualmente.'
argument-hint: 'Informe a página/fluxo alterado e o caminho dos screenshots já capturados (test/system ou tmp/screenshots).'
user-invocable: true
---

# Relatório de Teste Manual de UI

## Objetivo
Dar a quem vai validar a feature (humano, não a IA) um documento com prints de cada tela relevante e o passo a passo para reproduzir e testar na mão — sem precisar ler o diff ou reexecutar a suíte de testes.

## Quando usar
- Ao final de qualquer tarefa que alterou UI, depois de `ui-system-test` já ter coberto o caminho feliz + edge case com teste de sistema verde.
- Não substitui `ui-system-test`: reaproveita os screenshots que ele já capturou em `tmp/screenshots/`, não recaptura do zero.
- Se a tarefa rodou via `dev-harness`, é chamado na fase "Ao concluir" quando a mudança envolveu UI.

## Procedimento
1. Confirme que `ui-system-test` já rodou e que os PNGs relevantes existem em `tmp/screenshots/`. Se faltar print de algum estado importante do fluxo, capture antes de seguir (mesmo mecanismo: `page.save_screenshot`).
2. Crie `tmp/qa/<feature-ou-fluxo>.md` (crie o diretório se não existir; `tmp/` já é ignorado pelo git).
3. Para cada tela/estado relevante do fluxo, na ordem em que o usuário vai encontrá-las:
   - Embuta a imagem com caminho relativo (`![Descrição](../screenshots/arquivo.png)`).
   - Uma frase dizendo o que a imagem mostra.
4. Escreva o passo a passo de teste manual: pré-condições (seed/fixture usada, se houver), passos numerados de navegação e clique, e o resultado esperado em cada passo — inclua o caminho feliz e o(s) edge case(s) cobertos pelo teste de sistema.
5. Não repita o diff de código nem decisões de implementação — isso é para *testar*, não para revisar código.

## Modelo de saída (`tmp/qa/<feature>.md`)
- Título curto do fluxo/feature.
- Pré-condições (dados, seed, usuário logado, etc.).
- Screenshots com legenda, na ordem do fluxo.
- Passo a passo numerado (ação → resultado esperado), cobrindo caminho feliz + edge case(s).
- Riscos ou estados não cobertos, se houver.

## Saída esperada
- Caminho do arquivo `.md` gerado.
- Confirmação de que os prints referenciados existem e abrem corretamente.
