# D&D Combat Simulator

Projeto Rails para modelar personagens de Dungeons & Dragons 5e e simular combates entre equipes, com foco em avaliar dificuldade prática de encounters por meio de execuções repetidas, logs e métricas de resultado.

## Objetivo

O objetivo principal deste repositório não é apenas cadastrar personagens ou classes, mas evoluir um simulador de combate que permita responder perguntas como:
- qual a taxa de vitória de uma composição contra outra;
- quantas rodadas um encontro costuma durar;
- que mecânicas alteram mais o resultado agregado de um combate.

## Stack

- Ruby on Rails 8
- Phlex para UI
- Tailwind CSS
- SQLite no desenvolvimento, com suporte a PostgreSQL

## Estado atual da arquitetura

- `EncounterService` sustenta o fluxo de combate atual e deve ser tratado como implementação provisória e congelada fora de refatorações explícitas.
- O caminho de evolução do combate está no pipeline `Combat::*`, que introduz ações, resolução de efeitos e execução estruturada.
- A documentação arquitetural descreve tanto o comportamento atual quanto a direção incremental de refatoração.

Pontos de entrada recomendados:
- [.okf/index.md](.okf/index.md)
- [.okf/architecture/overview.md](.okf/architecture/overview.md)
- [.okf/architecture/encounter-service.md](.okf/architecture/encounter-service.md)
- [.okf/architecture/combat-effect-pipeline.md](.okf/architecture/combat-effect-pipeline.md)

## Setup rápido

```bash
bundle install
yarn install
bin/rails db:create db:migrate
./bin/dev
```

## Rodando testes

```bash
bin/rails test
```

Para focar em uma área específica:

```bash
bin/rails test test/models
bin/rails test test/services
bin/rails test test/integration
```

## Navegação rápida por intenção

Se você quer:

- entender a arquitetura geral: [.okf/architecture/overview.md](.okf/architecture/overview.md)
- entender o combate atual: [.okf/architecture/encounter-service.md](.okf/architecture/encounter-service.md)
- trabalhar no pipeline novo de habilidades e efeitos: [.okf/architecture/combat-effect-pipeline.md](.okf/architecture/combat-effect-pipeline.md)
- entender os modelos e persistência: [.okf/models/index.md](.okf/models/index.md)
- entender a modelagem de habilidades: [.okf/models/class-feature.md](.okf/models/class-feature.md)
- seguir instruções para agentes de IA: [.instructions.md](.instructions.md)

## Restrições importantes

- Não expanda `EncounterService` fora de uma refatoração explícita do sistema de combate.
- Prefira o pipeline `Combat::*` para novas mecânicas executáveis.
- Ao alterar regras de combate, valide comportamento mecânico e não apenas estrutura de código.

## Status da documentação

O diretório [docs](docs) concentra a documentação oficial do projeto.

O diretório [tmp](tmp) pode conter checkpoints de trabalho e notas de pesquisa usadas durante sessões com IA. Esses arquivos não devem ser tratados automaticamente como documentação oficial do sistema.
