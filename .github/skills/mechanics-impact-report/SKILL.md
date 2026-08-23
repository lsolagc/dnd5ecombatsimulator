---
name: mechanics-impact-report
description: 'Documente o impacto mecânico de uma mudança além do diff de código. Use para registrar o que mudou no comportamento do combate, como foi validado e quais riscos permanecem.'
argument-hint: 'Descreva a mudança mecânica e os resultados observados nos testes/simulações.'
user-invocable: true
---

# Registro de Impacto Mecânico

## Objetivo
Manter histórico técnico do efeito real das mudanças de regra.

## Quando usar
- Qualquer alteração que mude resultado de combate.
- Mudanças com delta observável em simulação.
- Decisões de design de mecânica.

## Procedimento
1. Registre comportamento anterior relevante.
2. Registre o comportamento novo e as diferenças objetivas.
3. Liste validações executadas (testes e simulações).
4. Aponte métricas afetadas e magnitude do impacto.
5. Declare riscos, limitações e hipóteses em aberto.
6. Vincule decisões a contratos/documentação atualizados.

## Modelo de saída
- Contexto
- Mudança mecânica
- Evidências
- Impacto observado
- Riscos residuais
