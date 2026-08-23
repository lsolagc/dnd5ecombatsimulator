---
name: reproducible-rolls
description: 'Garanta reprodutibilidade em rolagens e simulações com seed e controle de aleatoriedade. Use para reproduzir bugs e validar mudanças sem ruído excessivo.'
argument-hint: 'Informe seed desejada, escopo do teste e comportamento esperado.'
user-invocable: true
---

# Rolagem Reproduzível

## Objetivo
Permitir repetição confiável de resultados em testes e simulações.

## Quando usar
- Bug intermitente em combate.
- Comparação antes/depois de mudança mecânica.
- Testes automatizados sensíveis a RNG.

## Procedimento
1. Defina e registre seed explícita para cada execução.
2. Isole fontes de aleatoriedade fora do escopo do teste.
3. Evite dependências de ordem não determinística no setup.
4. Execute múltiplas rodadas com a mesma seed para confirmar repetibilidade.
5. Em caso de variação, rastreie pontos de RNG não controlados.
6. Documente seed, ambiente e versão avaliada.

## Checklist
- Seed registrada
- Resultado repetido com a mesma configuração
- Divergências explicadas
