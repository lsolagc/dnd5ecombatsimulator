---
name: simulation-evaluation-metrics
description: 'Padronize avaliação quantitativa de simulações. Use para definir métricas, limiares e formato de comparação entre execuções, evitando conclusões subjetivas.'
argument-hint: 'Descreva a hipótese, métrica principal e critério de aprovação/reprovação.'
user-invocable: true
---

# Evals e Métricas de Simulação

## Objetivo
Converter mudanças mecânicas em sinais objetivos de qualidade.

## Quando usar
- Alteração de regra com impacto em combate.
- Validação de estabilidade entre versões.
- Investigação de regressão difícil de detectar por leitura de código.

## Procedimento
1. Defina hipótese mensurável.
2. Escolha métricas primárias e secundárias.
3. Defina limiares de aceitação e critério de falha.
4. Execute experimento com amostra e seeds controladas.
5. Consolide comparativo baseline vs atual.
6. Classifique resultado: aprovado, reprovado ou inconclusivo.

## Métricas recomendadas
- Taxa de vitória por lado
- Rounds médios
- Dano médio por round
- Dano concentrado por alvo
- Sobrevivência média

## Saída esperada
- Hipótese
- Metodologia
- Métricas e limiares
- Resultado final com justificativa
