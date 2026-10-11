---
name: safe-change-sensitive-area
description: 'Conduza mudanças em áreas sensíveis com alto risco de regressão, especialmente no loop de turnos do CombatSimulatorService. Use para limitar escopo, validar impactos e reduzir acoplamento acidental.'
argument-hint: 'Descreva a mudança proposta, a área sensível afetada e o risco principal.'
user-invocable: true
---

# Mudança Segura em Área Sensível

## Objetivo
Executar alterações com segurança em partes acopladas ou de alto risco de regressão.

## Quando usar
- Mudança no loop de turnos do `CombatSimulatorService` (ordem de iniciativa, ordem de sorteios do RNG,
  formato do `round_log`, desfecho).
- Ajuste com alto risco de regressão silenciosa.

## Procedimento
1. Defina a fronteira exata da mudança e o que fica fora de escopo.
2. Levante contratos atuais que não podem ser quebrados.
3. Priorize a abordagem de menor impacto com testes de regressão.
4. Valide comportamento antes e depois com casos representativos.
5. Registre riscos residuais e plano de rollback lógico.
6. Atualize a documentação quando houver novo limite ou decisão arquitetural.

## Regras
- Não mudar a sequência de sorteios do RNG sem dizer que os resultados com a mesma seed mudam.
- Preferir o pipeline de efeitos para novas mecânicas quando possível.
