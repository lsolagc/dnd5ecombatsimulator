# Sistema de Combate

## Visão Geral

O sistema de combate orquestra encontros entre equipes de combatentes. A `EncounterService` gerencia:
- Iniciativa (baseada em DEX)
- Rodadas de combate
- Ataques e dano
- Condições especiais (imunidade, resistência, vulnerabilidade)

## Status Atual

`EncounterService` existe hoje como uma implementação intencionalmente simples para viabilizar o fluxo de combate atual.

Ela ainda está fortemente acoplada ao restante do sistema de combate e ao modelo de dados disponível neste momento. Por isso, mudanças estruturais neste serviço tendem a exigir ajustes em outras partes da aplicação.

Enquanto a refatoração mais ampla do sistema de combate não acontecer, `EncounterService` deve ser tratado como código congelado: use-o como referência do comportamento atual, mas não expanda nem reestruture esse serviço sem que a refatoração maior faça parte do escopo.

## EncounterService

### Inicialização

Observação: a API atual do serviço documenta o comportamento existente, não um contrato definitivo para a arquitetura futura.

```ruby
encounter = EncounterService.new(team_1, team_2)
```

**Parâmetros:**
- `team_1` - Array de combatentes (PlayerCharacter, etc)
- `team_2` - Array de combatentes

**Inicialização:**
1. Copia HP current para ambas equipes
2. Rola iniciativa (d20 + DEX modifier) para cada combatente
3. Ordena por iniciativa (maior primeiro)

### Execução

```ruby
result = encounter.call
```

**Retorna:**
```ruby
{
  rounds: 6,
  winner: team_1,
  events: [
    {round: 1, attacker: char1, target: char2, attack_roll: 18, damage: 7},
    ...
  ]
}
```

## Loop de Combate

```
├─ Ronda 1
│  ├─ Combatente A ataca Combatente C
│  │  ├─ Rola d20 + ataque bonus
│  │  ├─ Se acerta: rolar dano
│  │  └─ Aplicar dano com modificadores
│  │
│  ├─ Combatente B ataca Combatente D
│  ├─ Combatente C ataca Combatente B
│  └─ Combatente D ataca Combatente A
│
├─ [Se time vencido, fim]
├─ Ronda 2
│  ├─ [Mesma sequência]
│  └─ [Continua até morte]
```

## AttackRoll

### Rolar Ataque

```ruby
Dice::AttackRoll.new(
  ability_modifier: attacker.strength_modifier,
  proficiency_bonus: attacker.proficiency_bonus,
  advantage: false,
  disadvantage: false
).roll
```

**Componentes:**
1. **Base**: d20 (1-20)
2. **Modificadores:**
   - `+ability_modifier` (STR/DEX conforme arma)
   - `+proficiency_bonus` (se proficiente)
3. **Vantagem/Desvantagem:**
   - Advantage: rola 2d20, toma maior
   - Disadvantage: rola 2d20, toma menor

### Críticos

```
Natural 20 = Acerto crítico
- Sempre acerta
- Dano dobrado (rola 2x o dado de dano)

Natural 1 = Falha
- Sempre erra
```

## RollResult

```ruby
result = Dice::RollResult.new(
  total: 18,
  critical: false,
  failure: false
)

result.total      # => 18
result.critical?  # => false
result.failure?   # => false
result.hit?       # => true (>= AC alvo)
```

## Dano e Modificadores

### Dano Base

```rust
damage = roll_damage_dice + ability_modifier

Exemplo:
- Espada longa (1d8): rola 6
- STR modifier: +3
- Total: 6 + 3 = 9 dano
```

### Condições de Dano

Cada ataque pode ter:
- `damage_type`: string (slashing, piercing, bludgeoning, fire, cold, etc)
- `conditions`: array (blindness, prone, poisoned, etc)

### Resistências e Imunidades

```ruby
# Se alvo tem resistência
damage = (base_damage / 2).round

# Se alvo tem imunidade
damage = 0

# Se alvo tem vulnerabilidade
damage = base_damage * 2
```

## Hit Points em Combate

### Rastreamento

Cada combatente tem:
- `max_hp` - HP total calculado na criação do personagem
- `current_hp` - HP atual em combate

### Morte

```
current_hp <= 0 → Combatente incapacitado
Equipe com todos incapacitados → Derrota
```

## Dados de Combate

### Estrutura do Evento

```ruby
{
  round: 1,
  attacker: player_character_1,
  target: player_character_2,
  attack_roll: {
    total: 18,
    critical: false,
    failure: false
  },
  is_hit: true,
  damage: 7,
  damage_type: "slashing",
  target_hp_before: 10,
  target_hp_after: 3
}
```

## Exemplos de Combate

### Round 1: Fighter vs Goblin

```
Fighter (HP: 15, STR +3, Prof +2)
Goblin (HP: 7, AC: 15)

Fighter attacks:
  - Roll: d20 = 12, +3 STR +2 Prof = 17 total
  - 17 vs AC 15 → Hit!
  - Damage: 1d8 = 5, +3 STR = 8 pontos de dano
  - Goblin: 7 - 8 = -1 (Morte)

Resultado: Fighter vence
```

### Round 1-3: Wizard vs Wizard

```
Wizard A (HP: 8, INT +2, Prof +2)
Wizard B (HP: 8, INT +2, Prof +2)

Round 1:
  A attacks: Roll 14 → Hit for 4 damage. B: 8 → 4 HP
  B attacks: Roll 12 → Miss! B: 4 HP

Round 2:
  A attacks: Roll 16 → Hit for 5 damage. B: 4 → -1 (Morte)

Resultado: Wizard A vence
```

---

Consulte [Sistema de Classes](class-system.md) para como a proficiência afeta ataques.
