---
type: Pipeline
title: Combat effect-execution pipeline (Combat::*)
description: The path every combat action takes in CombatSimulatorService — the basic Attack action, class features and spells — through CombatAction, EffectResolver, EffectExecutor, ActionRunner, and the RollExpression roll layer.
resource: app/services/combat
tags: [combat, evolution]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-17T00:00:00Z
verified: { by: human:lsolagc, at: 2026-10-11T18:30:17Z }
sources:
  - id: combat-pipeline-rb
    title: app/services/combat/*.rb
    resource: ../../app/services/combat
status: stable
---

# Overview

The `Combat::*` pipeline is the path every combat action takes in
[CombatSimulatorService](/architecture/combat-simulator-service.md), from the
basic Attack action every combatant has to class features and spells. An
action's **effect** is its atomic outcome: the Attack action's effect is
weapon damage on a hit, the same shape as a spell attack such as Fire Bolt.
The vocabulary (action, attack, effect) is defined in
[combat-action-language.md](/architecture/combat-action-language.md). Phase 1
(shipped March 2026) delivered a reusable contract for executing
class-feature effects — proven end-to-end with `Second Wind` — without
pushing new logic into the since-removed `EncounterService`.[^combat-pipeline-rb]

Delivered in this phase: the `CombatAction` → `EffectResolver` →
`EffectExecutor` pipeline (run via `Combat::ActionRunner`), the
`RollExpression`/`RollContext`/`RollOutcome` roll layer, and the
`effect_payload` JSONB field on `class_feature_unlocks` that lets a class
feature declare an executable effect declaratively.[^combat-pipeline-rb]

A later increment (September 2026) added a minimal `:spell` source_type
alongside `:class_feature` — see [spell.md](/models/spell.md) — proven
end-to-end the same way Second Wind was: through `Combat::ActionRunner` and
`PlayerCharacter#cast_spell`, with a real, enforced spell-slot resource. It
is scoped to a single class (Fighter's Eldritch Knight): no spell lists,
upcasting, or control conditions.

Since October 2026 the basic **Attack action** runs through the pipeline too
(`source_type: :attack`, see below), so weapon attacks, spell attacks and
class-feature damage share one hit rule, one crit rule and one damage
application.

Out of scope so far: control conditions in the pipeline, the action economy
(action / bonus action / reaction / rider, see
[combat-action-language.md](/architecture/combat-action-language.md)), and
full transactional rest-based resource/recharge management (Action Surge,
Ki).[^combat-pipeline-rb] See
[combat-migration-strategy.md](/architecture/combat-migration-strategy.md)
for the phased plan that gets there.

# Contract

**1. Intent — `Combat::CombatAction`**
```ruby
action = Combat::CombatAction.new(
  source_type: :class_feature,
  source_id: feature.id,
  actor: fighter,
  targets: []
)
```

**The Attack action — `source_type: :attack`.** `source_id` is nil: the
`EffectResolver` derives the payload from the actor's equipped weapon —
`kind: damage`, `roll: "<damage_dice> ± weapon_damage_modifier"`, the weapon's
`damage_type`, `target: enemy`, `attack: weapon` — and raises `ArgumentError`
on a malformed die instead of letting `RollExpression` read it as a variable
worth 0. `Combat::ActionRunner.attack(action:, next_target:,
advantage_against:, attacks:)` makes up to `attacks` weapon attacks, by default
`attacks_per_action` (Extra Attack; War Magic's bonus asks for 1). Before each one it calls `next_target`, so an attack that follows a
kill goes to another target and `nil` ends the action; the caller's block sees
each `(target, result, advantage)` before the next target is picked. Target
choice stays with the caller (the simulator's gambits, War Magic focus or
random pick); the pipeline only asks for "the next target".

**2. Resolution — `Combat::EffectResolver`** turns a `CombatAction` into one
or more atomic `Combat::EffectInstance` objects (`heal`, `damage`,
`apply_condition`, `grant_temp_hp`, `resource_change`).

**3. Execution — `Combat::EffectExecutor`** applies an `EffectInstance` to
combat state and returns a `Result` carrying `kind`, `applied`, `amount`,
`hp_before`/`hp_after`, a `roll_outcome`, the `saving_throw` and the
`attack_roll` (each nil when the effect has none); no human-readable message
(removed 2026-10-17).[^combat-pipeline-rb]

**4. Orchestration — `Combat::ActionRunner`** runs resolver + executor for a
`CombatAction` in one call: `Combat::ActionRunner.call(action:)`.

**Rolls** are expressed via `RollExpression` (e.g. `"1d10 + fighter_level"`),
evaluated against a `RollContext` (actor, target, level, modifiers), and
produce a `RollOutcome` carrying the resolved expression, dice, individual
rolls, modifiers, and total — so combat log/UI/audit can show the full
breakdown instead of just a final number.[^combat-pipeline-rb]

# Data shape: `effect_payload`

`class_feature_unlocks.effect_payload` (jsonb) declares the effect an
`EffectResolver` turns into an `EffectInstance`. For a class feature the
resolver reads the effect in force at the actor's level
(`ClassFeature#effect_payload_at`: an unlock without a payload inherits the
one before it; see [class-feature-unlock.md](/models/class-feature-unlock.md)):

```json
{ "kind": "heal", "roll": "1d10 + fighter_level", "target": "self" }
```

`"target"` is the valid-target indicator: `"self"` (the actor), `"enemy"` (a
member of the opposing party) or `"ally"` (a member of the actor's own party,
actor included). The pipeline itself only distinguishes `self` from "the
`targets` it was handed"; it is `CombatSimulatorService` that enforces
`enemy`/`ally` when choosing the target.

Two more optional keys are read only by `CombatSimulatorService`, not by the
pipeline: `"applies_to": "weapon_attack"` (the effect rides on a weapon attack
instead of being an action of its own) and `"debuff": "next_attack_advantage"`
(mark the target, see [combat-simulator-service.md](/architecture/combat-simulator-service.md)).
`ActionRunner.call` / `EffectExecutor.call` accept `crit:` so an effect riding on
a critical weapon hit doubles its dice.

Damage effects can also declare `"attack": "spell"` or `"attack": "weapon"` (an
attack roll against the target's AC; a miss sets `applied: false` and deals 0; a
natural 20 always hits, a natural 1 always misses, otherwise total >= AC —
`Dice.hit?`; a critical hit doubles the dice via `RollExpression#resolve(crit:
true)`, never the flat modifier). A spell attack rolls with
`PlayerCharacter#spell_attack_bonus` and crits on a natural 20; a weapon attack
rolls with `#weapon_attack_bonus` (attack bonus + passive bonuses such as
Archery) and crits at `#critical_hit_threshold` (19 for a Champion). `advantage:`
on `EffectExecutor.call` rolls the d20 twice and keeps the higher. Damage is
applied with the **effect's** `damage_type` (the attacker's weapon), so the
target's resistance, immunity or vulnerability to *that* type applies.
`EffectExecutor::Result` carries the rolled `attack_roll` (an
`EffectExecutor::AttackRoll`: natural, total, armor_class, hit, crit; nil when
the effect made none) next to `saving_throw`.

Effects can also declare a `save` whose `"dc"` is either a fixed integer or
`"spell"`, meaning the actor's `spell_save_dc`; spell attack and save numbers
come from the spellcasting ability resolved by
`PlayerCharacter#spellcasting_ability`. Unsupported `attack` values are rejected
at `EffectInstance` construction.

This is the field that connects the persisted class-feature model (see
[models/class-feature-unlock.md](/models/class-feature-unlock.md)) to this
pipeline: a class feature's unlock row describes an executable effect
without new orchestrator logic.[^combat-pipeline-rb]

[^combat-pipeline-rb]: Source: `app/services/combat/*.rb`
