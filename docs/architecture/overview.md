# Visão Geral da Arquitetura

## O que é?

**D&D Character Manager** é um sistema Rails para gerenciar campanha de D&D 5e:
- Criar e gerenciar personagens com ability scores
- Definir classes com progressão de níveis (1-20)
- Executar encontros de combate entre equipes

## Arquitetura de Alto Nível

```
┌─────────────────────────────────────┐
│         Camada de Apresentação      │
│   (Controladores + Views Phlex)     │
└────────────────┬────────────────────┘
                 │
┌────────────────▼────────────────────┐
│      Camada de Lógica de Negócio    │
│     (Services + Validadores)        │
└────────────────┬────────────────────┘
                 │
┌────────────────▼────────────────────┐
│     Camada de Modelos (ActiveRecord)   │
│  (PlayerCharacter, PlayerClass,        │
│   ClassLevelProgression, Combatant)    │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│     Base de Dados (SQLite/PostgreSQL)   │
└──────────────────────────────────────────┘
```

## Componentes Principais

### 1. **Modelos de Dados**
- `PlayerCharacter` - Personagem do jogador
- `PlayerClass` - Classe (Wizard, Fighter, etc)
- `ClassLevelProgression` - Tabela de progressão 1-20
- `Combatant` - Entidade em combate (polimórfico)

### 2. **Controladores**
- `PlayerCharactersController` - CRUD de personagens
- `PlayerClassesController` - CRUD de classes
- `HomeController` - Página inicial

### 3. **Serviços**
- `EncounterService` - Orquestra combates completos
- `LevelUpService` - Aplica aumentos de nível

### 4. **Componentes UI** (Phlex)
- `Components::Base` - Base com helpers Rails
- `Components::Layout` - Layout e sidebar
- `Components::PlayerClassComponents` - Forms de classe
- `RubyUI` - Biblioteca customizada (buttons, forms, tables)

## Fluxo de Dados

### Criação de Personagem

```
POST /player_characters
    ↓
PlayerCharactersController#create
    ↓
Validar atributos (ability scores)
    ↓
Criar PlayerCharacter + associar PlayerClass
    ↓
Calcular HP inicial baseado em class.hit_die
    ↓
Redirect para show
```

### Execução de Combate

```
EncounterService.prepare(team1, team2)
    ↓
Rolar iniciativa (DEX mod)
    ↓
Loop de rodadas:
    - Cada combatente ataca (AttackRoll)
    - Aplicar dano com resistências/imunidades
    - Remover se HP ≤ 0
    ↓
Retornar time vencedor
```

## Patterns Utilizados

### Polimorfismo
`Combatant` usa `belongs_to :combatable, polymorphic: true` para permitir diferentes tipos de combatentes.

### Serviços
Lógica complexa (combate, level-up) fica em `app/services/` separada dos modelos.

### Validadores Customizados
`ConditionAndDamageTypeFormatValidator` valida formato de dano/condição.

### View Components (Phlex)
Views são componentes Phlex reutilizáveis em `app/components/`.

## Fluxo de Requisições Rails

```
GET /player_characters/:id
    ↓
PlayerCharactersController#show
    ↓
@character = PlayerCharacter.find(id)
    ↓
render @character (Phlex component)
    ↓
HTML response
```

---

Consulte [Sistema de Classes](class-system.md) e [Sistema de Combate](combat-system.md) para detalhes específicos.
