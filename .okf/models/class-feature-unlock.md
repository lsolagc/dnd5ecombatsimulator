---
type: Model
title: ClassFeatureUnlock
description: Per-level unlock/scaling row for a ClassFeature, and the bridge to the combat effect pipeline via the declarative effect_payload field.
resource: app/models/class_feature_unlock.rb
tags: [class, feature, combat, persistence, passive]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-11T00:00:00Z
verified: { by: human:lsolagc, at: 2026-10-11T21:06:51Z }
sources:
  - id: unlock-rb
    title: app/models/class_feature_unlock.rb
    resource: ../../app/models/class_feature_unlock.rb
  - id: issue-45
    title: "GitHub issue #45: status system (5e conditions, buffs and debuffs with duration)"
    resource: https://github.com/lsolagc/dnd5ecombatsimulator/issues/45
status: stable
---

# Overview

`ClassFeatureUnlock` `belongs_to :class_feature` and controls at which level
(1-20) a feature appears or scales — e.g. Action Surge grants 1 use at level
2 and 2 uses at level 17.[^unlock-rb] Per-level fields
(`action_type`, `recharge_type`, `resource_name`) **override** the parent
`ClassFeature`'s values when the rule changes at that level; `uses` /
`uses_formula` (e.g. `proficiency_bonus`, `wisdom_modifier`) express fixed vs.
variable resource pools.[^unlock-rb]

`effect_payload` (jsonb) is the field that connects this persisted model to
the [combat effect-execution pipeline](/architecture/combat-effect-pipeline.md):
it lets an unlocked feature describe an executable effect (`kind`, `roll`,
`target` — `self`, `enemy` or `ally`, the valid-target indicator — …) without pushing new logic into
[CombatSimulatorService](/architecture/combat-simulator-service.md).[^unlock-rb]
`Combat::EffectResolver` reads this payload to build the runtime
`EffectInstance`.

Beyond the active-use shape, `effect_payload` also carries an optional
`trigger` (`"always"`, `"turn_start"`, `"turn_end"`) and `conditions` map —
this is how passive effects (Champion's improved critical, HP-threshold
heals/damage) are declared without a `CombatAction`. See
[passive-effect-triggers.md](/architecture/passive-effect-triggers.md) for
the full trigger/condition contract, which `PlayerCharacter` reads directly
rather than through `Combat::EffectResolver`.

A Battle Master maneuver's payload also carries `applies_to: weapon_attack`
(and Distracting Strike `debuff: next_attack_advantage`), which
`CombatSimulatorService` reads to run the maneuver as a rider on a weapon attack
— see [combat-simulator-service.md](/architecture/combat-simulator-service.md).
`debuff` is a single string with one supported value, so its shape will change
once other features or spells apply a [status](/ubiquitous-language.md) with
a duration; [issue #45](https://github.com/lsolagc/dnd5ecombatsimulator/issues/45)
plans it as part of the status system.[^issue-45]

**Persisted vs. executed** — the model defines *what* a feature is;
[the pipeline](/architecture/combat-effect-pipeline.md) defines *how* it runs
in an encounter. `CombatAction`, `EffectInstance`, executor results, and
`RollOutcome` are runtime-only and never persisted.[^unlock-rb]

# Schema

| Field | Type | Description |
|-------|------|-------------|
| class_feature_id | integer (FK) | → `class_features` |
| level | integer | 1-20 |
| action_type | enum | Optional override |
| recharge_type | enum | Optional override |
| uses | integer | Fixed uses at this level |
| uses_formula | string | Variable-use formula |
| resource_name | string | Optional override |
| description | text | Level-specific description |
| notes | text | Optional |
| effect_payload | jsonb | Declarative executable effect, e.g. `{ "kind": "heal", "roll": "1d10 + fighter_level", "target": "self" }` |

Index: `index_class_feature_unlocks_on_class_feature_id_and_level` (unique).

[^unlock-rb]: Source: `app/models/class_feature_unlock.rb`

[^issue-45]: Source: GitHub issue #45: status system (5e conditions, buffs and debuffs with duration)
