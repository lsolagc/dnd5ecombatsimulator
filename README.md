# D&D Combat Simulator

Projeto Rails para modelar personagens de Dungeons & Dragons 5e e simular combates entre equipes, com foco em avaliar dificuldade prática de encounters por meio de execuções repetidas, logs e métricas de resultado.

## Objetivo

O objetivo principal deste repositório não é apenas cadastrar personagens ou classes, mas evoluir um simulador de combate que permita responder perguntas como:
- qual a taxa de vitória de uma composição contra outra;
- quantas rodadas um encontro costuma durar;
- que mecânicas alteram mais o resultado agregado de um combate.

## Stack

- Ruby on Rails 8
- ERB + Bootstrap para UI
- SQLite no desenvolvimento, com suporte a PostgreSQL

## Estado atual da arquitetura

- `Combat::Simulator` é o orquestrador de combate oficial: combates com seed, ataques, habilidades de classe, magias e gambits.
- Mecânicas executáveis passam pelo pipeline `Combat::*`, que introduz ações, resolução de efeitos e execução estruturada.
- A documentação arquitetural descreve tanto o comportamento atual quanto a direção incremental de refatoração.

Pontos de entrada recomendados:
- [.okf/index.md](.okf/index.md)
- [.okf/architecture/overview.md](.okf/architecture/overview.md)
- [.okf/architecture/combat-simulator.md](.okf/architecture/combat-simulator.md)
- [.okf/architecture/combat-effect-pipeline.md](.okf/architecture/combat-effect-pipeline.md)

## Setup rápido

```bash
bundle install
yarn install
bin/rails db:create db:migrate
./bin/dev
```

Ou, sem terminal aberto: `docker compose up -d` sobe Postgres, o portal (web, Sass e workers) em
http://localhost:3000 e o visualizador do OKF em http://localhost:8808, e eles voltam sozinhos quando
o Docker inicia. Os testes rodam lá dentro também: `docker compose exec app bin/rails test` (e
`test:system`). Detalhes em [.okf/ops/dev-setup.md](.okf/ops/dev-setup.md).

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
- entender o combate atual: [.okf/architecture/combat-simulator.md](.okf/architecture/combat-simulator.md)
- trabalhar no pipeline novo de habilidades e efeitos: [.okf/architecture/combat-effect-pipeline.md](.okf/architecture/combat-effect-pipeline.md)
- entender os modelos e persistência: [.okf/models/index.md](.okf/models/index.md)
- entender a modelagem de habilidades: [.okf/models/class-feature.md](.okf/models/class-feature.md)
- seguir instruções para agentes de IA: [.instructions.md](.instructions.md)

## Restrições importantes

- Prefira o pipeline `Combat::*` para novas mecânicas executáveis.
- Ao alterar regras de combate, valide comportamento mecânico e não apenas estrutura de código.

## Status da documentação

O diretório [docs](docs) concentra a documentação oficial do projeto.

O diretório [tmp](tmp) pode conter checkpoints de trabalho e notas de pesquisa usadas durante sessões com IA. Esses arquivos não devem ser tratados automaticamente como documentação oficial do sistema.
