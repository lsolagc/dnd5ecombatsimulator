---
type: Model
title: PlayerCharacter
description: The player's character record — name, class, and level — delegating all in-combat stats (ability scores, HP, armor class) to its Combatant, and hosting the attack/damage/passive-trigger behavior used in combat.
resource: app/models/player_character.rb
tags: [persistence, combat]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-14T00:00:00Z
verified: { by: human:lsolagc, at: 2026-10-11T21:21:20Z }
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
`attr_accessor` on the `CombatantBehavior` concern.[^combatant-behavior-rb] In-combat HP is therefore
transient, per Ruby object instance, matching how
[CombatSimulatorService](/architecture/combat-simulator-service.md) resets
it at the start of an encounter rather than reading a stored value.

`has_one :combatant, as: :combatable, touch: true` creates the `Combatant`
automatically on `before_create` if one is not already present.[^player-character-rb]
`accepts_nested_attributes_for :combatant` additionally lets callers build and
populate that `Combatant` up front, via a `combatant_attributes` hash — this
is how the [character-creation wizard](/ui/erb-bootstrap-views.md) writes
ability scores, `armor_class`, and `speed` in the same form submit that
creates the `PlayerCharacter`.[^player-character-rb]

# HP and leveling

Without a `max_hit_points_input` override, `max_hit_points` is **full HP for the
level** (`full_hit_points`): `hit_points_at_level_one` (`hit_die_value +
constitution_modifier`) plus `hit_die_value + constitution_modifier` for every
level above 1 — the maximum of the hit die at every level, no rolling, so it
is deterministic. The wizard's HP preview (`hpPreview` in `wizard_controller.js`)
mirrors the same formula. An override replaces the computed value. There is no `level_up!` method or `LevelUpService` in
the current codebase — level-up support was removed; `level` is set at
creation and not changed by application code today.

# Attacks and damage

In combat, a weapon attack runs through the pipeline as the Attack action
(see [combat-effect-pipeline.md](/architecture/combat-effect-pipeline.md)),
which reads these from the character:[^player-character-rb]

- `weapon_attack_bonus`: the combatant's `attack_bonus` plus passive
  `attack_bonus` modifiers (Fighting Style: Archery's +2).
- `weapon_damage_modifier`: `strength_modifier` plus passive `damage_bonus`
  modifiers (Fighting Style: Dueling's +2).
- `damage_dice`: default `"1d4"`. It must be a single `NdM` die.
- `damage_type`: default `"bludgeoning"`, configured per character via the
  creation/edit wizard.
- `critical_hit_threshold`: the natural roll a weapon attack crits on.

`take_damage(amount:, damage_type:)` applies the target's
immunity/resistance/vulnerability (delegated to `Combatant`, see
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

A class feature runs through
[the combat effect-execution pipeline](/architecture/combat-effect-pipeline.md)
via `Combat::CombatAction` + `Combat::ActionRunner`, built by
[CombatSimulatorService](/architecture/combat-simulator-service.md).

`spellcasting_ability` returns the ability name the character casts with: the
chosen subclass's spellcasting feature (`spellcasting_feature`) wins, falling
back to the class's `spellcasting_modifier` — so an Eldritch Knight gets
`"intelligence"` although Fighter has none, and non-casting subclasses get
`nil`. It is an ability *name*; `spellcasting_ability_modifier` is the numeric
modifier (raising when the character has no ability), and from it
`spell_save_dc` = `8 + proficiency_bonus + modifier` and `spell_attack_bonus` =
`proficiency_bonus + modifier`. The combat pipeline reads them for spell attacks
and `"dc": "spell"` saves — see
[combat-effect-pipeline.md](/architecture/combat-effect-pipeline.md).

# Cached class lookups

`unlocked_class_feature_unlocks` (behind every passive: attack and AC
modifiers, critical threshold, turn passives), `class_progression` (attacks
per action, proficiency bonus) and `spellcasting_feature` are cached on the
instance, keyed by what they depend on (`player_class_id`, `level`,
`martial_archetype_id`, `fighting_style_id`): changing one of those on the
same instance recomputes, and `#reload` clears the cache. The combat loop asks
for them on every attack, and [CombatSimulatorService](/architecture/combat-simulator-service.md)
builds fresh instances per simulation. Rows edited in the database while an
instance is alive (unlocks, progressions) are not seen until `reload`.

# Schema

| Field | Type | Description |
|-------|------|-------------|
| name | string | Character name |
| level | integer | Default 1; no in-app way to change it today |
| player_class_id | integer (FK) | → `player_classes` |

[^player-character-rb]: Source: `app/models/player_character.rb`

[^combatant-behavior-rb]: Source: `app/models/concerns/combatant_behavior.rb`
