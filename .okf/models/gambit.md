---
type: Model
title: "Gambit"
description: One FFXII-style turn rule (target + condition → action) owned by a PlayerCharacter or a GambitPreset, up to 6 per owner, evaluated by position in CombatSimulatorService.
resource: app/models/gambit.rb
tags: [model, combat, gambits]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-09T00:30:00Z
sources:
  - id: gambit-rb
    title: app/models/gambit.rb
    resource: ../../app/models/gambit.rb
  - id: gambit-test
    title: test/models/gambit_test.rb
    resource: ../../test/models/gambit_test.rb
status: draft
---

# Overview

A `Gambit` belongs to a polymorphic `owner` ([PlayerCharacter](/models/player-character.md)
`has_many :gambits, -> { order(:position) }, as: :owner`). It is data only:
[CombatSimulatorService](/architecture/combat-simulator-service.md) evaluates the
enabled ones top to bottom.[^gambit-rb]

- `target`: `self` / `ally` / `enemy` (prefixed: `target_self?`).
- `condition` (enum in code, prefixed `condition_*`): `any`, `hp_below` /
  `hp_above` (`condition_value` 1..99 %), `lowest_hp`, `highest_hp`, `marked`,
  `unmarked`, `resource_at_least` (`condition_value` 1..20; rejected with Ataque
  and cantrips). New values are appended, never renumbered.
- Action: `action_kind` `attack` (no record) / `class_feature` (FK) / `spell` (FK).
  A DB check constraint keeps the FKs consistent with the kind.
- The target must fit the action's natural target (attack → enemy; payload
  `self`/`enemy` → same; `ally` → ally or self), read from the highest-level unlock
  that has a payload; passive (`trigger`) and non heal/damage payloads are
  rejected. Action Surge (no payload) is accepted with target Self. A rule naming an action its owner lacks is valid and skipped at runtime.
- `position` 1..6 (check constraint), at most 6 per owner, and a unique
  `(owner_type, owner_id, position)` constraint **deferrable initially deferred**, so a
  reorder can permute positions inside one transaction.[^gambit-test]
- `Gambit.copy_rules(from:, to:)` is the only copy (preset save, overwrite and apply): in one
  transaction holding a row lock on `to`, deletes `to`'s rules and creates new rows from `from`'s in
  priority order, positions 1..n. Returns false, changing nothing, when `from` has none. No link is kept.
- `GambitPreset` (`app/models/gambit_preset.rb`): `name` stripped, unique case-insensitively (validation
  + unique index on `lower(name)`); `has_many :gambits, as: :owner`. Created and used only from a
  character's gambits screen (Presets panel).
- `label` renders the rule in PT-BR, e.g. `Inimigo: HP < 50% → Ataque`.

Decisions behind the model: [gambits-decisions.md](/architecture/gambits-decisions.md).
