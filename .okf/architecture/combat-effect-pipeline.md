---
type: Pipeline
title: Combat effect-execution pipeline (Combat::*)
description: The incremental replacement path for combat mechanics — CombatAction, EffectResolver, EffectExecutor, ActionRunner, and the RollExpression roll layer — meant to carry class-feature and future spell effects without expanding EncounterService.
resource: app/services/combat
tags: [combat, pipeline, evolution]
generated:
  by: copilot-cli/claude-sonnet-5
  at: 2026-08-21T23:39:26Z
sources:
  - id: combat-pipeline-rb
    title: app/services/combat/*.rb
    resource: ../../app/services/combat
status: stable
---

# Overview

The `Combat::*` pipeline is the evolution path for combat mechanics beyond
the basic attack loop in the frozen
[encounter-service.md](/architecture/encounter-service.md). Phase 1 (shipped
March 2026) delivered a reusable contract for executing class-feature effects
— proven end-to-end with `Second Wind` — without pushing new logic into
`EncounterService`.[^combat-pipeline-rb]

Delivered in this phase: the `CombatAction` → `EffectResolver` →
`EffectExecutor` pipeline (run via `Combat::ActionRunner`), the
`RollExpression`/`RollContext`/`RollOutcome` roll layer, and the
`effect_payload` JSONB field on `class_feature_unlocks` that lets a class
feature declare an executable effect declaratively.[^combat-pipeline-rb]

Out of scope for this phase: migrating the basic attack from
`EncounterService` onto `CombatAction`, spells and control conditions in the
same pipeline, and full transactional resource/recharge management (Action
Surge, Ki, spell slots).[^combat-pipeline-rb] See
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

**2. Resolution — `Combat::EffectResolver`** turns a `CombatAction` into one
or more atomic `Combat::EffectInstance` objects (`heal`, `damage`,
`apply_condition`, `grant_temp_hp`, `resource_change`).

**3. Execution — `Combat::EffectExecutor`** applies an `EffectInstance` to
combat state and returns a `Result` carrying `kind`, `applied`, `amount`,
`hp_before`/`hp_after`, a `roll_outcome`, and a `message`.[^combat-pipeline-rb]

**4. Orchestration — `Combat::ActionRunner`** runs resolver + executor for a
`CombatAction` in one call: `Combat::ActionRunner.call(action:)`.

**Rolls** are expressed via `RollExpression` (e.g. `"1d10 + fighter_level"`),
evaluated against a `RollContext` (actor, target, level, modifiers), and
produce a `RollOutcome` carrying the resolved expression, dice, individual
rolls, modifiers, and total — so combat log/UI/audit can show the full
breakdown instead of just a final number.[^combat-pipeline-rb]

# Data shape: `effect_payload`

`class_feature_unlocks.effect_payload` (jsonb) declares the effect an
`EffectResolver` turns into an `EffectInstance`:

```json
{ "kind": "heal", "roll": "1d10 + fighter_level", "target": "self" }
```

This is the field that connects the persisted class-feature model (see
[models/class-feature-unlock.md](/models/class-feature-unlock.md)) to this
pipeline: a class feature's unlock row describes an executable effect
without new `EncounterService` logic.[^combat-pipeline-rb]

# Model shortcut

`PlayerCharacter#use_class_feature(slug:, targets: [])` builds the
`CombatAction` and delegates to `Combat::ActionRunner`, so callers do not
construct the intent object by hand.
