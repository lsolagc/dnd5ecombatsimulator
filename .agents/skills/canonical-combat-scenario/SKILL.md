---
name: canonical-combat-scenario
description: 'Defina e mantenha cenários canônicos de combate para comparação entre versões. Use para criar baseline estável de regressão mecânica e balanceamento.'
argument-hint: 'Informe classes/builds, nível, inimigos, seed e tamanho da amostra desejada.'
user-invocable: true
---

# Cenário Canônico de Combate

## Objetivo
Estabelecer cenários de referência reproduzíveis para medir o impacto de mudanças.

## Quando usar
- Antes de alterar mecânicas centrais.
- Em regressão de comportamento de combate.
- Em comparação de balanceamento entre versões.

## Procedimento
1. Defina a composição dos lados: participantes, níveis, atributos e equipamentos relevantes.
2. Fixe parâmetros globais: seed, limite de rounds, regras ativas e critério de término.
3. Execute o baseline com amostra suficiente para reduzir ruído.
4. Salve os resultados-padrão: taxa de vitória, rounds médios, dano total e distribuições.
5. Reexecute após a mudança e compare o delta contra o baseline.
6. Documente o contexto do experimento e a conclusão.

## Saída esperada
- Definição do cenário
- Baseline
- Resultado pós-mudança
- Delta e interpretação
