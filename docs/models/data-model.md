# Modelo de Dados

## Diagrama ER

```
PlayerClass
├─ id (PK)
├─ name
├─ hit_die (enum: d4-d12)
├─ spellcasting_modifier (enum: int/wis/cha/none)
├─ description
└─ created_at, updated_at
   │
   ├─ has_many :class_level_progressions
   └─ has_many :player_characters

ClassLevelProgression
├─ id (PK)
├─ player_class_id (FK)
├─ level (1-20)
├─ proficiency_bonus
├─ grants_ability_score_improvement
├─ attacks_per_action (default: 1)
└─ created_at, updated_at

ClassFeature
├─ id (PK)
├─ player_class_id (FK)
├─ name
├─ slug
├─ feature_type
├─ action_type
├─ resource_name
├─ recharge_type
├─ grants_spellcasting
├─ source_book
├─ source_reference
├─ notes
└─ created_at, updated_at
  │
  └─ has_many :class_feature_unlocks

ClassFeatureUnlock
├─ id (PK)
├─ class_feature_id (FK)
├─ level
├─ action_type
├─ recharge_type
├─ uses
├─ uses_formula
├─ resource_name
├─ description
├─ notes
├─ effect_payload (json/jsonb)
└─ created_at, updated_at

PlayerCharacter
├─ id (PK)
├─ player_class_id (FK)
├─ name
├─ strength (ability score)
├─ dexterity
├─ constitution
├─ intelligence
├─ wisdom
├─ charisma
├─ current_level
├─ proficiency_bonus
├─ max_hp
├─ current_hp
├─ created_at, updated_at
│
├─ belongs_to :player_class
├─ has_one :combatant
└─ validates: ability scores (1-20), class

Combatant (Polimórfico)
├─ id (PK)
├─ combatable_type (string: "PlayerCharacter")
├─ combatable_id (FK)
├─ current_hp
├─ proficiency_bonus
├─ initiative_modifier
├─ created_at, updated_at
│
├─ belongs_to :combatable (polimórfico)
└─ validates: HP > 0
```

## Tabelas

### player_classes

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| id | integer | PK |
| name | string | Nome da classe |
| hit_die | integer | Enum (0=d4, 1=d6, 2=d8, 3=d10, 4=d12) |
| spellcasting_modifier | integer | Enum (0=int, 1=wis, 2=cha, 3=none) |
| description | text | Descrição |
| created_at | datetime | |
| updated_at | datetime | |

### class_level_progressions

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| id | integer | PK |
| player_class_id | integer | FK para player_classes |
| level | integer | 1-20 |
| proficiency_bonus | integer | +2 a +6 |
| grants_ability_score_improvement | boolean | Nível concede ASI |
| attacks_per_action | integer | Quantos ataques por ação (padrão: 1) |
| created_at | datetime | |
| updated_at | datetime | |

**Regra atual do Guerreiro (D&D 5e):**
- Níveis 1-4: `attacks_per_action = 1`
- Níveis 5-10: `attacks_per_action = 2`
- Níveis 11-19: `attacks_per_action = 3`
- Nível 20: `attacks_per_action = 4`

### class_features

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| id | integer | PK |
| player_class_id | integer | FK para player_classes |
| name | string | Nome da habilidade |
| slug | string | Chave estável por classe |
| description | text | Descrição funcional |
| feature_type | integer | Tipo da habilidade |
| action_type | integer | Tipo de ação base |
| resource_name | string | Nome do recurso associado |
| recharge_type | integer | Regra de recarga |
| grants_spellcasting | boolean | Marca habilidades que concedem conjuração |
| source_book | string | Livro de origem |
| source_reference | string | Referência curta |
| notes | text | Observações |
| created_at | datetime | |
| updated_at | datetime | |

### class_feature_unlocks

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| id | integer | PK |
| class_feature_id | integer | FK para class_features |
| level | integer | Nível de desbloqueio/escala |
| action_type | integer | Override do tipo de ação |
| recharge_type | integer | Override da recarga |
| uses | integer | Usos fixos no nível |
| uses_formula | string | Fórmula de usos variáveis |
| resource_name | string | Override do nome do recurso |
| description | text | Descrição específica do marco |
| notes | text | Observações |
| effect_payload | json/jsonb | Definição declarativa do efeito executável |
| created_at | datetime | |
| updated_at | datetime | |

`effect_payload` conecta a persistência ao pipeline `Combat::*`. Ele permite que uma habilidade desbloqueada descreva um efeito executável sem empurrar nova lógica para o `EncounterService`.

### player_characters

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| id | integer | PK |
| player_class_id | integer | FK para player_classes |
| name | string | Nome do personagem |
| strength | integer | 1-20 (ability score) |
| dexterity | integer | 1-20 |
| constitution | integer | 1-20 |
| intelligence | integer | 1-20 |
| wisdom | integer | 1-20 |
| charisma | integer | 1-20 |
| current_level | integer | 1-20 (padrão: 1) |
| proficiency_bonus | integer | +2 a +6 |
| max_hp | integer | Calculado |
| current_hp | integer | Máx na criação |
| created_at | datetime | |
| updated_at | datetime | |

### combatants

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| id | integer | PK |
| combatable_type | string | "PlayerCharacter" (polimórfico) |
| combatable_id | integer | FK |
| current_hp | integer | HP em combate |
| proficiency_bonus | integer | Bônus ativo |
| initiative_modifier | integer | DEX modifier |
| created_at | datetime | |
| updated_at | datetime | |

## Relacionamentos

### PlayerClass → ClassLevelProgression
Uma classe tem muitas tabelas de progressão (uma por nível).

```ruby
class PlayerClass < ApplicationRecord
  has_many :class_level_progressions
end

class ClassLevelProgression < ApplicationRecord
  belongs_to :player_class
end
```

### PlayerClass → PlayerCharacter
Uma classe pode ter muitos personagens.

```ruby
class PlayerClass < ApplicationRecord
  has_many :player_characters
end

class PlayerCharacter < ApplicationRecord
  belongs_to :player_class
end
```

### PlayerClass → ClassFeature → ClassFeatureUnlock
Uma classe possui várias habilidades, e cada habilidade pode ter vários marcos de desbloqueio ou escala.

```ruby
class PlayerClass < ApplicationRecord
  has_many :class_features
end

class ClassFeature < ApplicationRecord
  belongs_to :player_class
  has_many :class_feature_unlocks
end

class ClassFeatureUnlock < ApplicationRecord
  belongs_to :class_feature
end
```

### PlayerCharacter → Combatant
Um personagem pode ser parte de um combate (polimórfico).

```ruby
class PlayerCharacter < ApplicationRecord
  has_one :combatant, as: :combatable
end

class Combatant < ApplicationRecord
  belongs_to :combatable, polymorphic: true
end
```

## Validações

### PlayerClass
- `name`: presença, unicidade
- `hit_die`: presença, enum válido
- `spellcasting_modifier`: presença, enum válido

### PlayerCharacter
- `name`: presença
- `player_class_id`: presença
- Ability scores: presença, entre 1-20
- `current_hp`: presença, ≤ max_hp

### Combatant
- `combatable_type` e `combatable_id`: presença
- `current_hp`: presença, ≥ 0

### ClassFeature
- `player_class_id`: presença
- `name`: presença
- `slug`: presença, unicidade por classe
- `feature_type`, `action_type`, `recharge_type`: presença e enum válido

### ClassFeatureUnlock
- `class_feature_id`: presença
- `level`: presença, entre 1-20
- `effect_payload`: opcional, mas quando presente deve seguir contrato aceito pelo pipeline de efeitos

## Ability Scores

D&D 5e usa 6 ability scores, cada um variando de 1-20:

| Score | Ability | Rails Column | Modifier Calc |
|-------|---------|--------------|---------------|
| STR | Strength | strength | (value - 10) / 2 |
| DEX | Dexterity | dexterity | (value - 10) / 2 |
| CON | Constitution | constitution | (value - 10) / 2 |
| INT | Intelligence | intelligence | (value - 10) / 2 |
| WIS | Wisdom | wisdom | (value - 10) / 2 |
| CHA | Charisma | charisma | (value - 10) / 2 |

**Exemplos de Modificadores:**
```
Score 1-2:   -5 modifier
Score 3-4:   -4 modifier
Score 8-9:   -1 modifier
Score 10-11: +0 modifier
Score 12-13: +1 modifier
Score 16-17: +3 modifier
Score 20:    +5 modifier
```

## Enums

### hit_die
```ruby
d4:  0  # Sorcerer
d6:  1  # Rogue
d8:  2  # Cleric
d10: 3  # Fighter
d12: 4  # Barbarian
```

### spellcasting_modifier
```ruby
int:  0  # Wizard
wis:  1  # Cleric
cha:  2  # Sorcerer
none: 3  # Fighter
```

## Persistência vs Execução de Combate

Nem tudo que participa do combate é persistido da mesma forma.

### Persistido
- classes, progressão e personagens;
- habilidades (`class_features`) e desbloqueios (`class_feature_unlocks`);
- definição declarativa de efeitos em `effect_payload`.

### Executado em memória
- `Combat::CombatAction`;
- `Combat::EffectInstance`;
- `Combat::EffectExecutor::Result` e resultados equivalentes de execução;
- rolagens estruturadas como `RollOutcome`.

Essa separação é importante porque o modelo persistido define o que uma habilidade é, enquanto o pipeline de combate define como ela é executada em um encontro.

---

Consulte [Visão Geral](../architecture/overview.md) para fluxo de dados.
