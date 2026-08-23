---
name: declarative-effect-implementation
description: 'Adicione habilidades via pipeline declarativo de efeitos. Use para criar efeito novo com payload, resolução, execução, testes e documentação, evitando expandir a lógica legada no EncounterService.'
argument-hint: 'Descreva o efeito desejado, regras 5e envolvidas e comportamento esperado.'
user-invocable: true
---

# Adição de Efeito Declarativo

## Objetivo
Criar ou evoluir mecânicas no pipeline Combat::* com contrato explícito e cobertura de teste.

## Quando usar
- Habilidade nova de classe.
- Ação com dano, cura, condição ou efeito persistente.
- Refino de payload declarativo existente.

## Procedimento
1. Defina o contrato do payload: campos obrigatórios, opcionais e defaults.
2. Implemente resolução e execução no pipeline de efeitos.
3. Garanta observabilidade mínima: resultado legível e logs suficientes para diagnóstico.
4. Escreva testes de unidade e integração do caminho principal e edge cases.
5. Verifique compatibilidade com resistências, imunidades, vulnerabilidades e crítico, quando aplicável.
6. Atualize a documentação técnica do contrato e dos exemplos.

## Checklist
- Payload validado
- Execução determinística quando a seed for controlada
- Testes passando
- Documentação atualizada
