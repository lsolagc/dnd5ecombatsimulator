---
type: Model
title: "Gambit"
description: One FFXII-style turn rule (target + condition → action) owned by a PlayerCharacter or a GambitPreset, up to 6 per owner, evaluated by position in CombatSimulatorService.
resource: app/models/gambit.rb
tags: [combat, gambits]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-15T00:00:00Z
verified: { by: human:lsolagc, at: 2026-10-11T21:20:29Z }
sources:
  - id: gambit-rb
    title: app/models/gambit.rb
    resource: ../../app/models/gambit.rb
  - id: gambit-test
    title: test/models/gambit_test.rb
    resource: ../../test/models/gambit_test.rb
  - id: issue-46
    title: "GitHub issue #46: gambit owner on Combatant once monsters exist"
    resource: https://github.com/lsolagc/dnd5ecombatsimulator/issues/46
status: stable
---

# Overview

A `Gambit` belongs to a polymorphic `owner` ([PlayerCharacter](/models/player-character.md)
`has_many :gambits, -> { order(:position) }, as: :owner`). It is data only:
[CombatSimulatorService](/architecture/combat-simulator-service.md) evaluates the
enabled ones top to bottom.[^gambit-rb]

Caveat: once a monster model exists, the owner could be the
[Combatant](/models/combatant.md) instead of the `PlayerCharacter`, since
`Combatant` is already the supertype of everything that fights (a monster
would be another `combatable` type). The polymorphic owner does not require
it, and a monster's actions need a new `action_kind` either way;
[issue #46](https://github.com/lsolagc/dnd5ecombatsimulator/issues/46) weighs
it, not planned soon.[^issue-46]

- `target`: `self` / `ally` / `enemy` (prefixed: `target_self?`).
- `condition` (enum in code, prefixed `condition_*`): `any`, `hp_below` /
  `hp_above` (`condition_value` 1..99 %), `lowest_hp`, `highest_hp`, `marked`,
  `unmarked`, `resource_at_least` (`condition_value` 1..20; rejected with Ataque
  and cantrips). New values are appended, never renumbered.
- Action: `action_kind` `attack` (no record) / `class_feature` (FK) / `spell` (FK).
  A DB check constraint keeps the FKs consistent with the kind.
- The target must fit the action's natural target (attack → enemy; payload
  `self`/`enemy` → same; `ally` → ally or self), read from the feature's effect at the
  owner's level (`ClassFeature#action_payload_at`, the same function the simulator uses): a
  character's rule at the character's level, a preset's (no level) at the feature's highest
  unlock with a payload; passive (`trigger`) and non heal/damage payloads are rejected. Action Surge (no payload) is accepted with target Self. A rule naming an action its owner lacks is valid and skipped at runtime: a feature from another subclass, or one with no effect yet at the owner's level (checked like a preset's, at the feature's highest unlock). Only a feature the owner has, whose effect at its level does not fit the target, makes the rule invalid.
- `position` 1..6 (check constraint), at most 6 per owner, and a unique
  `(owner_type, owner_id, position)` constraint **deferrable initially deferred**, so a
  reorder can permute positions inside one transaction.[^gambit-test]
- `Gambit.copy_rules(from:, to:)` is the only copy (preset save, overwrite and apply): in one
  transaction holding a row lock on `to`, deletes `to`'s rules and creates new rows from `from`'s in
  priority order, positions 1..n. Returns false, changing nothing, when `from` has none. No link is kept.
  Each copy is validated for `to`: a rule that does not hold at the character's level raises
  `ActiveRecord::RecordInvalid` and changes nothing, and the gambits screen answers 422 naming the
  rule (position and label) and why. Applying a preset is all or nothing.
- `GambitPreset` (`app/models/gambit_preset.rb`): `name` stripped, unique case-insensitively (validation
  + unique index on `lower(name)`); `has_many :gambits, as: :owner`. Created and used only from a
  character's gambits screen (Presets panel).
- `label` renders the rule in PT-BR, e.g. `Inimigo: HP < 50% → Ataque`.

Decisions behind the model: [gambits-decisions.md](/architecture/gambits-decisions.md); measured effect: [gambits-impact.md](/architecture/gambits-impact.md).

[^gambit-rb]: Source: `app/models/gambit.rb`

[^gambit-test]: Source: `test/models/gambit_test.rb`

[^issue-46]: Source: GitHub issue #46: gambit owner on Combatant once monsters exist
