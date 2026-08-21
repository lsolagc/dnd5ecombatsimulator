---
type: Pipeline
title: Passive effect triggers (always / turn_start / turn_end)
description: The trigger + conditions extension to effect_payload that lets class features declare passive modifiers and turn-based heal/damage without going through CombatAction — the mechanism behind the Champion subclass's improved critical.
tags: [combat, pipeline, passive]
generated:
  by: copilot-cli/claude-sonnet-5
  at: 2026-08-21T23:00:00Z
sources:
  - id: player-character-rb
    title: app/models/player_character.rb
    resource: ../../app/models/player_character.rb
  - id: seeds
    title: db/seeds.rb
    resource: ../../db/seeds.rb
status: stable
---

# Overview

Alongside the active-use `effect_payload` shape consumed by
[the combat effect-execution pipeline](/architecture/combat-effect-pipeline.md)
(`kind`/`roll`/`target` via `Combat::CombatAction` → `Combat::EffectResolver`
→ `Combat::EffectExecutor`), `effect_payload` supports a second, passive
shape read directly by [PlayerCharacter](/models/player-character.md), with
no `CombatAction` involved:

```json
{ "trigger": "always", "kind": "modifier", "modifier": "critical_hit_threshold", "value": 19 }
```

```json
{ "trigger": "turn_start", "kind": "heal", "roll": "1d6", "target": "self",
  "conditions": { "current_hp_lte_max_hp_fraction": 0.5 } }
```

# Trigger values

- **`always`** — read continuously, not once per turn. Today the only
  consumer is `PlayerCharacter#critical_hit_threshold`, which collects every
  unlocked `"always"` + `kind: "modifier"` + `modifier:
  "critical_hit_threshold"` payload and takes the **lowest** declared value
  (defaulting to 20 when none apply) — this is exactly how the Champion
  Fighter subclass's improved-critical passive is modeled, purely as
  data.[^player-character-rb][^seeds]
- **`turn_start`** / **`turn_end`** — read by
  `apply_start_of_turn_passives!` / `apply_end_of_turn_passives!`. Each
  matching, condition-satisfying payload with `kind: "heal"` or `kind:
  "damage"` is turned into a `Combat::EffectInstance` via
  `Combat::EffectInstance.from_payload` and applied with
  `Combat::EffectExecutor.call(effect:, actor: self, target: self)` — always
  self-targeted; a non-`"self"` `target` on a passive is silently skipped
  (`apply_passive_effect_payload` returns `nil` unless `target_type ==
  "self"`).

Neither trigger is orchestrated by
[CombatSimulatorService](/architecture/combat-simulator-service.md) or
[EncounterService](/architecture/encounter-service.md) today — both hooks
exist on `PlayerCharacter` but nothing in either orchestrator currently
calls `apply_start_of_turn_passives!`/`apply_end_of_turn_passives!` during a
round. Treat them as implemented-but-not-yet-wired-into-the-turn-loop.

# `conditions`

Optional map of predicates, all of which must hold (`passive_conditions_met?`):

| Key | Meaning |
|-----|---------|
| `current_hp_gt` | `current_hit_points > value` |
| `current_hp_gte` | `current_hit_points >= value` |
| `current_hp_lt` | `current_hit_points < value` |
| `current_hp_lte` | `current_hit_points <= value` |
| `current_hp_lte_max_hp_fraction` | `current_hit_points <= max_hit_points * value` |

An absent `conditions` map always passes.
