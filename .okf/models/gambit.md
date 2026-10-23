---
type: Model
title: "Gambit"
description: One FFXII-style turn rule (target + condition → action) owned by a PlayerCharacter or a GambitPreset, up to 6 per owner, evaluated by position in Combat::GambitPolicy.
resource: app/models/gambit.rb
tags: [combat, gambits]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-22T00:00:00Z
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
[Combat::GambitPolicy](/architecture/combat-simulator.md) evaluates the
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
  unlock with a payload; passive (`trigger`) and non heal/damage payloads are rejected. An `extra_action` feature (Action Surge, found by that kind, `Gambit#action_surge?`) is accepted with target Self only. A rule naming an action its owner lacks is valid and skipped at runtime: a feature from another subclass, or one with no effect yet at the owner's level (checked like a preset's, at the feature's highest unlock). Only a feature the owner has, whose effect at its level does not fit the target, makes the rule invalid.
- At most `Gambit::MAX_PER_OWNER` (6) per owner: the ceiling lives only in that constant (validations
  `position` in 1..6 and `owner_has_room`); the database checks only `position >= 1`
  (`gambits_position_range`, relaxed in phase 4.1). A unique `(owner_type, owner_id, position)`
  constraint **deferrable initially deferred** lets a reorder permute positions inside one
  transaction.[^gambit-test]
- The list rules live in the `GambitOwner` concern (`app/models/concerns/gambit_owner.rb`, included by
  `PlayerCharacter` and `GambitPreset`, which also declares `has_many :gambits, -> { order(:position) },
  as: :owner`): positions stay contiguous 1..n and every write of them runs in `with_gambits_locked`
  (one transaction holding a row lock on the owner). `add_gambit(attributes)` (next position; returns
  the gambit, saved or with errors), `move_gambit(gambit, :up/:down)` (nothing moves at either end),
  `reorder_gambits(ids)` (false, changing nothing, unless an exact permutation of the owner's ids),
  `remove_gambit(gambit)` (compacts the rest; another owner's rule raises `RecordNotFound`), `replace_gambits(list_of_attributes)` (used by
  `lib/gambit_setups.rb`) and `copy_gambits_from(other)`. `GambitsController` keeps only the HTTP
  format checks (direction, ids) and calls these.
- `to.copy_gambits_from(from)` is the only copy (preset save, overwrite and apply): deletes `to`'s
  rules and creates new rows from `from`'s in priority order, positions 1..n. Returns false, changing
  nothing, when `from` has none. No link is kept.
  Each copy is validated for `to`: a rule that does not hold at the character's level raises
  `ActiveRecord::RecordInvalid` and changes nothing, and the gambits screen answers 422 naming the
  rule (position and label) and why. Applying a preset is all or nothing.
- `GambitPreset` (`app/models/gambit_preset.rb`): `name` stripped, unique case-insensitively (validation
  + unique index on `lower(name)`); owns its gambits through `GambitOwner`. Created and used only from a
  character's gambits screen (Presets panel).
- `label` renders the rule in PT-BR, e.g. `Inimigo: HP < 50% → Ataque`.

Decisions behind the model: [gambits-decisions.md](/architecture/gambits-decisions.md); measured effect: [gambits-impact.md](/architecture/gambits-impact.md).

[^gambit-rb]: Source: `app/models/gambit.rb`

[^gambit-test]: Source: `test/models/gambit_test.rb`

[^issue-46]: Source: GitHub issue #46: gambit owner on Combatant once monsters exist
