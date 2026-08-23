---
name: adversarial-review
description: 'Aplique revisão adversarial para contestar conclusões técnicas da IA e do time. Use para exigir hipóteses alternativas, evidências, limites e critérios verificáveis antes de aceitar uma decisão.'
argument-hint: 'Informe a decisão proposta, evidências atuais e o ponto de maior incerteza.'
user-invocable: true
---

# Revisão Adversarial

## Objetivo
Reduzir concordância automática e elevar a qualidade de decisões técnicas.

## Quando usar
- Decisão arquitetural com trade-offs relevantes.
- Mudança de regra com impacto de balanceamento.
- Recomendação da IA sem evidência suficiente.

## Procedimento
1. Declare a conclusão atual em termos testáveis.
2. Liste as premissas que sustentam a conclusão.
3. Proponha pelo menos 2 hipóteses alternativas plausíveis.
4. Defina evidências necessárias para confirmar/refutar cada hipótese.
5. Identifique limites da recomendação atual.
6. Reavalie a decisão com base nas evidências disponíveis.

## Saída esperada
- Conclusão inicial
- Hipóteses alternativas
- Evidências por hipótese
- Limites e riscos
- Recomendação final condicionada
