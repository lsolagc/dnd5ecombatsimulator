---
name: combat-mechanics-testing
description: 'Padronize testes de mecânicas de combate (acerto, crítico, dano, cura, resistência, imunidade, vulnerabilidade e edge cases). Use para transformar regras de jogo em contratos verificáveis.'
argument-hint: 'Informe a mecânica-alvo, entradas críticas e resultado esperado.'
user-invocable: true
---

# Testes de Mecânicas de Combate

## Objetivo
Criar cobertura de teste robusta para regras 5e suportadas no projeto.

## Quando usar
- Nova mecânica de combate.
- Correção de bug em cálculo de dano/ataque.
- Regressão reportada por simulação.

## Procedimento
1. Especifique o contrato da mecânica com casos normais e extremos.
2. Crie testes de unidade para fórmula e resolução da regra.
3. Adicione testes de integração para o fluxo completo, quando aplicável.
4. Cubra acerto, crítico, falha, modificadores e tipo de dano quando houver.
5. Garanta casos com resistência, imunidade e vulnerabilidade.
6. Evite dependência de RNG sem seed controlada.

## Saída esperada
- Lista de cenários cobertos
- Evidência de regressão protegida
- Lacunas remanescentes
