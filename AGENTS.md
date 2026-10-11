# Contexto do Projeto

D&D Combat Simulator: projeto Rails 8 (ERB + Bootstrap, SQLite em dev) para modelar personagens de D&D 5e
e simular combates entre equipes, medindo taxa de vitória, duração e impacto de mecânicas.

## Leitura obrigatória antes de qualquer tarefa

- [README.md](README.md) — visão geral, stack e setup.
- [.okf/index.md](.okf/index.md) — bundle de conhecimento (OKF), ponto de entrada.
- [.okf/architecture/overview.md](.okf/architecture/overview.md) — arquitetura geral.

## Pontos críticos de arquitetura

- `CombatSimulatorService` é o orquestrador de combate oficial e único (o antigo `EncounterService` foi
  removido em 2026-10-11). Ver [.okf/architecture/combat-simulator-service.md](.okf/architecture/combat-simulator-service.md).
- Mecânica nova (habilidades, magias, efeitos) entra pelo pipeline `Combat::*` (ações, resolução de
  efeitos, execução estruturada), chamado pelo simulador.
  Ver [.okf/architecture/combat-effect-pipeline.md](.okf/architecture/combat-effect-pipeline.md).

## Design system
- Antes de mexer em views ou estilos, leia docs/design-system/README.md.
- Tokens: docs/design-system/tokens.json.
- Guia de cada componente: docs/design-system/components/<Nome>/README.md. O preview.html de cada um
  é a referência visual; o bundle.css é só para os previews (no app, use Bootstrap 5.3 + application.scss).

## Comandos

```bash
bundle install && yarn install
bin/rails db:create db:migrate
./bin/dev                    # servidor local

bin/rails test               # suíte completa
bin/rails test test/models
bin/rails test test/services
bin/rails test test/integration

bundle exec rubocop          # lint (Omakase Ruby style)
```

## Convenções

- Estilo Ruby: Rubocop Omakase (`.rubocop.yml`), não introduzir regras próprias sem necessidade.
- Preferir alterações cirúrgicas; não tocar em código não relacionado à tarefa.
- Atualizar `.okf/` (bundle OKF) quando a mudança afetar arquitetura documentada.
- No GitHub Copilot, um hook `agentStop` ([.github/hooks/okf-maintain.json](.github/hooks/okf-maintain.json))
  força um turno extra pedindo `/okf maintain` quando o turno termina com alterações de código não
  commitadas fora de `.okf/`. **Esse hook não roda no Claude Code** (formato de outra ferramenta).

## Garantias por hooks (Claude Code)

Definidos em [.claude/settings.json](.claude/settings.json), scripts em [.claude/hooks/](.claude/hooks/).
Ao contrário das skills, executam fora do modelo:

- **Verificação obrigatória** (`Stop` e `SubagentStop` do `task-build`): se o código (`app/ lib/ db/
  config/ test/ bin/ Gemfile*`) mudou no turno e esse estado nunca foi verificado, o hook roda rubocop
  (arquivos `.rb` alterados) e `bin/rails test` de verdade. Vermelho bloqueia **uma vez** por estado,
  com o trecho da falha. Falha de infraestrutura (banco indisponível) não bloqueia, mas avisa.
- **Commit sem evidência** (`PreToolUse` em Bash): qualquer `git ... commit` (inclusive `git -C`,
  `git -c` e `bash -c`) roda a verificação e é negado se não estiver verde.
- **Aprovação antes do build** (`PreToolUse` em `Agent`): o spawn do `task-build` exige a seção
  "Decisões para Veto" no briefing e pergunta ao usuário (`ask`) antes de começar.
- **Revisor que executa** (`SubagentStop` do agente `task-review`, `.claude/agents/task-review.md`): só
  encerra com relatório completo, execução real da suíte, sabotagem comprovada (ou "Sem invariantes:
  <razão>") e o código restaurado. Bloqueia no máximo 2 vezes por revisor.
- **`/okf maintain` automático** (`Stop`): depois de um turno com código novo e verde, pede uma volta
  extra para sincronizar `.okf/` (versão Claude Code do hook do Copilot, com estado próprio). O
  dispatcher único (`stop-dispatch.sh`) roda o gate antes, para não pedir o okf com a suíte vermelha.
- **Retomada** (`SessionStart` em `compact|resume`): reinjeta as garantias e se o estado atual está verificado.
- A evidência (assinatura de conteúdo, comandos, contagem de testes) fica em
  `.git/claude-verify/evidence.json`. Os hooks só negam ou bloqueiam, nunca reescrevem comandos
  (rtk e caveman já reescrevem Bash e reescritas paralelas não são determinísticas).
- **Credenciais do banco de teste:** `DND_TEST_USER`/`DND_TEST_PASS` só existem em shell interativa
  (`~/.bashrc`). Os hooks usam `bash -ic` quando as variáveis não estão no ambiente; agentes que rodam
  `bin/rails test` à mão devem fazer o mesmo (`bash -ic 'bin/rails test'`).
- **Escape:** iniciar o Claude Code com `CLAUDE_GATE_OFF=1` desliga os dois gates.
- Contornos aceitos (não vale complexidade para fechá-los): editar os scripts por `sed` no Bash,
  `git commit-tree`, alias de git e `--no-verify`. Editar `.claude/hooks/` e `.claude/settings.json`
  pelas ferramentas Edit/Write é negado por `permissions.deny`.

## Para inicializadores de IA específicos

Este arquivo é a fonte única de contexto. Arquivos como `CLAUDE.md` ou
`.github/copilot-instructions.md` devem apenas apontar para este `AGENTS.md`
em vez de duplicar conteúdo.
