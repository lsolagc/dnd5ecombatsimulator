# Contexto do Projeto

D&D Combat Simulator: projeto Rails 8 (Phlex + Tailwind, SQLite em dev) para modelar personagens de D&D 5e
e simular combates entre equipes, medindo taxa de vitória, duração e impacto de mecânicas.

## Leitura obrigatória antes de qualquer tarefa

- [README.md](README.md) — visão geral, stack e setup.
- [.okf/index.md](.okf/index.md) — bundle de conhecimento (OKF), ponto de entrada.
- [.okf/architecture/overview.md](.okf/architecture/overview.md) — arquitetura geral.

## Pontos críticos de arquitetura

- `EncounterService` é o fluxo de combate atual: tratar como **implementação provisória e congelada**.
  Não refatorar fora de pedido explícito.
- O caminho de evolução é o pipeline `Combat::*` (ações, resolução de efeitos, execução estruturada).
  Ver [.okf/architecture/combat-effect-pipeline.md](.okf/architecture/combat-effect-pipeline.md).
- Há um terceiro sistema, `CombatSimulatorService`, que roda ataques e habilidades de classe lado a lado
  sem tocar em `EncounterService`. Antes de mexer em combate, checar qual dos três sistemas a tarefa afeta
  — ver [.okf/architecture/overview.md](.okf/architecture/overview.md).

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
- Um hook `agentStop` ([.github/hooks/okf-maintain.json](.github/hooks/okf-maintain.json)) força
  automaticamente um turno extra pedindo `/okf maintain` sempre que um turno termina com alterações
  de código não commitadas fora de `.okf/` — não é preciso lembrar manualmente de rodar o maintain.

## Para inicializadores de IA específicos

Este arquivo é a fonte única de contexto. Arquivos como `CLAUDE.md` ou
`.github/copilot-instructions.md` devem apenas apontar para este `AGENTS.md`
em vez de duplicar conteúdo.
