# Sistema de Classes e Progressão

## Visão Geral

O sistema de classes D&D 5e define como personagens ganham poder conforme sobem de nível. Cada classe tem:
- **Hit Die**: d4, d6, d8, d10 ou d12 (determina HP por nível)
- **Spellcasting Modifier**: INT, WIS ou CHA (determina dano de magia)
- **Progressão**: Tabela de níveis 1-20 com bônus de proficiência

## Modelos

### PlayerClass

```ruby
class PlayerClass < ApplicationRecord
  has_many :class_level_progressions
  has_many :player_characters
  
  enum hit_die: { d4: 0, d6: 1, d8: 2, d10: 3, d12: 4 }
  enum spellcasting_modifier: { int: 0, wis: 1, cha: 2, none: 3 }
end
```

**Campos principais:**
- `name` - Nome da classe (string)
- `hit_die` - Dado de vida (enum: d4-d12)
- `spellcasting_modifier` - Modificador para dano (enum: int/wis/cha/none)
- `description` - Descrição (text)

### ClassLevelProgression

```ruby
class ClassLevelProgression < ApplicationRecord
  belongs_to :player_class
  
  scope :sorted, -> { order(level: :asc) }
end
```

**Campos principais:**
- `player_class_id` - FK para classe
- `level` - Nível (1-20, integer)
- `proficiency_bonus` - Bônus de proficiência por nível (integer)
- `grants_ability_score_improvement` - Indica se o nível concede ASI (boolean)
- `attacks_per_action` - Número de ataques por Ação de Ataque (integer, padrão: 1)

**Dados tipicamente:**
```
Level 1:  +2 proficiency
Level 5:  +3 proficiency
Level 9:  +4 proficiency
Level 13: +5 proficiency
Level 17: +6 proficiency
```

## Cálculo de HP

### Nível 1
```
HP = hit_die_value + CON_modifier

Exemplo:
- Classe: Fighter (d10)
- hit_die_value = 10
- CON modifier = +2
- HP inicial = 10 + 2 = 12
```

### Níveis Subsequentes (2+)
```
HP += roll_hit_die + CON_modifier

Exemplo (nível 2):
- Roll hit_die (d10): 7
- CON modifier: +2
- HP antes: 12
- HP novo: 12 + (7 + 2) = 21
```

## Progressão de Personagem

### LevelUpService

```ruby
LevelUpService.new(combatant).call
```

**Responsabilidades:**
1. Incrementar `player_character.level`
2. Buscar nova `ClassLevelProgression` do nível
3. Atualizar `proficiency_bonus` do combatant
4. Retornar flags de progressão (`can_improve_ability_scores`, `attacks_per_action`)

**Fluxo:**
```ruby
result = LevelUpService.new(player_character: character).call

result.new_level
result.proficiency_bonus
result.can_improve_ability_scores
result.attacks_per_action
```

## Dados de Progressão

A tabela `ClassLevelProgression` é congelada (`freeze`) após ser recuperada do banco de dados, garantindo dados imutáveis durante execução.

```ruby
# Safe: dados não podem ser modificados em runtime
progression = combatant.player_class.class_level_progressions.find(level: 5)
progression.proficiency_bonus
# => 3
```

## Exemplos de Classe

### Fighter
- Hit Die: d10
- Spellcasting Modifier: none
- Progressão: +2, +2, +2, +2, +3, +3, +3, +3, +4, +4, +4, +4, +5, +5, +5, +5, +6, +6, +6, +6
- Multiataque (Ataque Extra):
  - Níveis 1-4: 1 ataque por ação
  - Níveis 5-10: 2 ataques por ação
  - Níveis 11-19: 3 ataques por ação
  - Nível 20: 4 ataques por ação

### Wizard
- Hit Die: d6
- Spellcasting Modifier: INT
- Progressão: idem Fighter

## Integração com Combate

Durante combate, o `proficiency_bonus` é usado para:
- Calcular bônus de ataque com armas de proficiência
- Calcular DC para salvaguardas de magia (9 + INT + proficiency)

O `attacks_per_action` define quantas rolagens de ataque o combatente executa no turno.

---

Consulte [Sistema de Combate](combat-system.md) para como ataques, HP e proficiência são usados em combate.
