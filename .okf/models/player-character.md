---
type: Model
title: PlayerCharacter
description: The player's character record — name, class, and level — delegating all in-combat stats (ability scores, HP, armor class) to its Combatant, and hosting the attack/damage/passive-trigger behavior used in combat.
resource: app/models/player_character.rb
tags: [model, character, persistence, combat]
generated:
  by: copilot-cli/claude-sonnet-5
  at: 2026-08-21T23:39:26Z
sources:
  - id: player-character-rb
    title: app/models/player_character.rb
    resource: ../../app/models/player_character.rb
  - id: combatant-behavior-rb
    title: app/models/concerns/combatant_behavior.rb
    resource: ../../app/models/concerns/combatant_behavior.rb
status: stable
---

# Overview

`PlayerCharacter` itself persists only `name`, `level`, and `player_class_id`.
All combat-facing stats — ability scores, `armor_class`, `max_hit_points`,
`proficiency_bonus`, resistances/vulnerabilities/immunities — are **not**
columns on this model; they live on its associated
[Combatant](/models/combatant.md) and are reached through delegation
(`delegate_ability_scores_to :combatant`, and the delegated combat accessors
added by `CombatantBehavior.behave_as_combatant`).[^player-character-rb] This
is a deliberate split from what earlier project documentation described: the
persisted "identity" record (`PlayerCharacter`) is thin, and the "sheet"
(scores, defenses, HP ceiling) is on `Combatant`.[^player-character-rb]

`current_hit_points` is **not persisted at all** — it is a plain
`attr_accessor` on the `CombatantBehavior` concern, reset to `max_hit_points`
by `initialize_for_combat`.[^combatant-behavior-rb] In-combat HP is therefore
transient, per Ruby object instance, matching how
[CombatSimulatorService](/architecture/combat-simulator-service.md) and
[EncounterService](/architecture/encounter-service.md) both reset it at the
start of an encounter rather than reading a stored value.

`has_one :combatant, as: :combatable, touch: true` creates the `Combatant`
automatically on `before_create` if one is not already present.[^player-character-rb]

# HP and leveling

Level 1: `hit_points_at_level_one` = `hit_die_value + constitution_modifier`.
Levels above 1: adds one hit-die roll + CON modifier per additional level
(`roll_hit_points`). There is no `level_up!` method or `LevelUpService` in
the current codebase — level-up support was removed; `level` is set at
creation and not changed by application code today.

# Attacks and damage

`roll_an_attack` builds a `Dice::AttackRoll` from a fixed `damage_roll`
(`"1d4"`), `strength_modifier`, and `critical_hit_threshold` — **not** the
`ability_modifier`/`proficiency_bonus`/`advantage`/`disadvantage` shape
described in the legacy combat-system docs; the current `Dice::AttackRoll`
contract is `to_hit_modifier:`, `damage_dice:`, `damage_modifier:`,
`critical_hit_threshold:`.[^player-character-rb] `get_attacked` compares the
roll's total to `armor_class` (delegated from `Combatant`) and, on a hit,
calls `take_damage` with a **hardcoded** `damage_type: :bludgeoning` — weapon
damage typing is not yet wired into this path. `take_damage` applies the
target's immunity/resistance/vulnerability (delegated to `Combatant`, see
[combatant.md](/models/combatant.md)) before subtracting from
`current_hit_points`, floored at 0.

# Critical hit threshold and passives (Champion)

`critical_hit_threshold` scans unlocked `class_feature_unlocks` for
`effect_payload`s with `trigger: "always"`, `kind: "modifier"`, and
`modifier: "critical_hit_threshold"`, and takes the lowest declared value
(default 20 — i.e. only a natural 20 crits) — this is how the Champion
subclass's improved-critical passive is modeled, entirely through
`effect_payload` data with no Champion-specific code.[^player-character-rb]
Full trigger/condition mechanics are documented in
[passive-effect-triggers.md](/architecture/passive-effect-triggers.md).

`apply_start_of_turn_passives!` / `apply_end_of_turn_passives!` run any
unlocked `heal`/`damage` `effect_payload` whose `trigger` is
`turn_start`/`turn_end` and whose `conditions` are met, applying them via
`Combat::EffectInstance.from_payload` + `Combat::EffectExecutor` directly —
bypassing `Combat::CombatAction`/`Combat::ActionRunner` entirely, since a
passive has no explicit actor intent to model.

# Class features

`use_class_feature(slug:, targets: [])` looks up the feature by `slug` on
the character's class and delegates to
[the combat effect-execution pipeline](/architecture/combat-effect-pipeline.md)
via `Combat::CombatAction` + `Combat::ActionRunner`.

# Schema

| Field | Type | Description |
|-------|------|-------------|
| name | string | Character name |
| level | integer | Default 1; no in-app way to change it today |
| player_class_id | integer (FK) | → `player_classes` |
