---
name: ui-system-test
description: 'Verifique mudanças de UI (Phlex/Turbo) navegando o app de verdade: cobertura de teste de sistema, print da tela e checagem visual pela IA. Use antes de reportar qualquer mudança de frontend como concluída.'
argument-hint: 'Informe a página/fluxo alterado, o caminho feliz esperado e qualquer edge case relevante.'
user-invocable: true
---

# Teste de Sistema e Checagem Visual de UI

## Objetivo
Garantir que mudança de UI funciona de verdade — não só "testes passam", mas a IA vendo a tela renderizada — reaproveitando a infraestrutura já existente (Capybara + Selenium headless Chrome em `test/system/`), sem introduzir ferramenta nova.

## Quando usar
- Página, componente Phlex ou fluxo de formulário novo ou alterado.
- Interação via Turbo Stream/Frame.
- Qualquer mudança de frontend antes de reportar a tarefa como concluída.

## Procedimento
1. Estenda ou crie teste em `test/system/*_test.rb` usando `ApplicationSystemTestCase` (já configurado com `driven_by :selenium, using: :headless_chrome`).
2. Cubra o caminho feliz e ao menos 1 edge case (erro de validação, estado vazio, etc.).
3. Use fixtures já existentes em `test/fixtures`; evite dados ad-hoc quando um fixture já serve.
4. Prefira asserts semânticos (`assert_selector`, `assert_text`, `assert_no_selector`) a seletor CSS frágil.
5. Nos pontos-chave do fluxo, capture a tela com `page.save_screenshot(Rails.root.join("tmp/screenshots/<nome>.png"))`.
6. Rode `bin/rails test test/system/<arquivo>_test.rb`.
7. Leia cada PNG gerado (ferramenta de leitura de imagem) antes de declarar a tarefa pronta — o teste verde não substitui ver a tela.
8. Se o estado da UI depender de rolagem/RNG, siga a skill `reproducible-rolls` para manter o print determinístico entre execuções.

## Exploração interativa (complementar, não é o gate de fitness)
Durante o desenvolvimento, iterar via Playwright MCP (`npx @playwright/mcp@latest`) é mais rápido que reescrever teste a cada ajuste: permite navegar, clicar e ler DOM/console em tempo real contra o servidor local (`bin/dev`). Use para explorar enquanto builda; o critério de "pronto" continua sendo o teste de sistema com screenshot revisado (passos 1–7), que é o que roda em CI e fica registrado como regressão.

### Nota de ambiente (WSL)
O navegador do Playwright MCP roda dentro do WSL, com binário próprio baixado pelo Playwright (Chromium/Firefox patched) — ele **não** controla o Chrome ou Firefox já instalado no Windows, mesmo em modo não-headless. Rodar headless dentro do WSL é o modo padrão e mais confiável (sem dependência de display). Se precisar ver a janela, modo headed já aparece na área de trabalho do Windows via WSLg (Windows 11), sem precisar de ponte para um browser externo.

## Checklist
- Teste de sistema cobrindo caminho feliz + edge case, verde.
- Screenshot(s) capturado(s) e revisado(s) pela IA.
- Sem erro de console/JS visível durante a navegação.
- RNG, se houver, com seed controlada (ver `reproducible-rolls`).

## Saída esperada
- Caminho do(s) teste(s) criado(s)/alterado(s).
- Resultado da execução (`bin/rails test test/system/...`).
- Screenshots capturados e o que foi observado neles.
- Riscos ou pontos de UX não cobertos, se houver.
