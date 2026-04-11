# Documentação do Projeto

Esta documentação descreve o estado atual do simulador de D&D 5e, com ênfase em combate, progressão de classes, modelagem de dados e direção de evolução da arquitetura.

## Comece pela intenção

Se você quer:

- entender o projeto rapidamente: [architecture/overview.md](architecture/overview.md)
- instalar e rodar localmente: [guides/setup.md](guides/setup.md)
- trabalhar no combate atual: [architecture/combat-system.md](architecture/combat-system.md)
- trabalhar no pipeline novo de habilidades e efeitos: [architecture/combat-effect-execution.md](architecture/combat-effect-execution.md)
- entender progressão de classes e multiataque: [architecture/class-system.md](architecture/class-system.md)
- entender os modelos persistidos: [models/data-model.md](models/data-model.md)
- entender a modelagem de habilidades de classe: [models/class-features-schema.md](models/class-features-schema.md)
- trabalhar na interface Phlex e RubyUI: [components/overview.md](components/overview.md)

## Mapa rápido da documentação

### Arquitetura
- [Visão Geral](architecture/overview.md): panorama da aplicação e das camadas.
- [Sistema de Classes](architecture/class-system.md): progressão, bônus de proficiência e ataques por ação.
- [Sistema de Combate](architecture/combat-system.md): fluxo atual de combate e restrições do `EncounterService`.
- [Execução de Efeitos em Combate](architecture/combat-effect-execution.md): pipeline incremental com `CombatAction`, resolver e executor.
- [Habilidades do Guerreiro (5e)](architecture/fighter-abilities-5e.md): referência de habilidades para modelagem.

### Modelos
- [Modelos de Dados](models/data-model.md): entidades, relacionamentos e campos persistidos.
- [Esquema de Habilidades de Classe](models/class-features-schema.md): estrutura de habilidades e desbloqueios.

### Guias
- [Setup do Projeto](guides/setup.md): instalação e execução local.
- [Criando Personagens](guides/creating-characters.md): fluxo funcional de criação.

### Componentes
- [Componentes UI](components/overview.md): componentes Phlex e integração com RubyUI.

## Leitura mínima por tipo de tarefa

### Mudanças no combate legado
Leia nesta ordem:
1. [architecture/overview.md](architecture/overview.md)
2. [architecture/combat-system.md](architecture/combat-system.md)
3. [models/data-model.md](models/data-model.md)

### Novas habilidades ou efeitos
Leia nesta ordem:
1. [architecture/combat-effect-execution.md](architecture/combat-effect-execution.md)
2. [models/class-features-schema.md](models/class-features-schema.md)
3. [architecture/fighter-abilities-5e.md](architecture/fighter-abilities-5e.md)

### Mudanças em persistência ou modelagem
Leia nesta ordem:
1. [models/data-model.md](models/data-model.md)
2. [models/class-features-schema.md](models/class-features-schema.md)
3. [architecture/overview.md](architecture/overview.md)

### Mudanças em UI e fluxo web
Leia nesta ordem:
1. [components/overview.md](components/overview.md)
2. [guides/creating-characters.md](guides/creating-characters.md)
3. [architecture/overview.md](architecture/overview.md)

## Convenções importantes

### Migrations
1. Gere migrations com o gerador do Rails.
2. Edite o arquivo gerado.
3. Não crie migrations manualmente com timestamp escrito à mão.

### Combate
- `EncounterService` representa o fluxo legado e não deve ser expandido fora de uma refatoração explícita.
- Novas mecânicas devem preferir o pipeline `Combat::*` quando o escopo permitir.

## Para agentes de IA

Antes de propor ou alterar código:
- leia [.instructions.md](../.instructions.md)
- use este arquivo como roteador de contexto
- selecione apenas a documentação necessária para a tarefa atual

---

Última atualização: Abril 2026
