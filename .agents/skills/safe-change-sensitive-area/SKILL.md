---
name: safe-change-sensitive-area
description: 'Conduza mudanças em áreas sensíveis com alto risco de regressão, especialmente ao redor de EncounterService. Use para limitar escopo, validar impactos e reduzir acoplamento acidental.'
argument-hint: 'Descreva a mudança proposta, a área sensível afetada e o risco principal.'
user-invocable: true
---

# Mudança Segura em Área Sensível

## Objetivo
Executar alterações com segurança em partes congeladas ou acopladas.

## Quando usar
- Mudança próxima do EncounterService.
- Ajuste com alto risco de regressão silenciosa.
- Correções em fluxo de combate legado.

## Procedimento
1. Defina a fronteira exata da mudança e o que fica fora de escopo.
2. Levante contratos atuais que não podem ser quebrados.
3. Priorize a abordagem de menor impacto com testes de regressão.
4. Valide comportamento antes e depois com casos representativos.
5. Registre riscos residuais e plano de rollback lógico.
6. Atualize a documentação quando houver novo limite ou decisão arquitetural.

## Regras
- Não expandir EncounterService sem escopo explícito de refatoração.
- Preferir o pipeline de efeitos para novas mecânicas quando possível.
