---
type: Overview
title: System Architecture Overview
description: High-level layering of the D&D 5e combat simulator — presentation, services, models, and database — and how a character-creation or combat request flows through them.
tags: [combat]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-11T00:00:00Z
verified: { by: human:lsolagc, at: 2026-10-11T20:56:05Z }
sources:
  - id: characters-controller
    title: app/controllers/player_characters_controller.rb
    resource: ../../app/controllers/player_characters_controller.rb
---

# Overview

The D&D Combat Simulator is a Rails 8 application for managing D&D 5e
characters and classes, and for simulating combat encounters between teams to
measure win rate, encounter duration, and the impact of specific mechanics.

It is layered as: a presentation layer (controllers + ERB views styled with
Bootstrap), a business-logic layer (services + validators), a persistence
layer (ActiveRecord models), and a database (SQLite in development, with
PostgreSQL support).

[Combat::Simulator](/architecture/combat-simulator.md) is the
single, official combat orchestrator. It runs class features and spells
through [the Combat::* effect pipeline](/architecture/combat-effect-pipeline.md);
[passive effect triggers](/architecture/passive-effect-triggers.md) are a
separate, data-driven mechanism on `PlayerCharacter`. The legacy
`EncounterService` was removed on 2026-10-11 — see
[combat-migration-strategy.md](/architecture/combat-migration-strategy.md).

# Character-creation flow

1. `PlayerCharactersController#create` accepts only `name`, `level`, and
   `player_class_id` — ability scores and other combat stats are **not**
   part of this form; they live on [Combatant](/models/combatant.md), which
   `PlayerCharacter` creates for itself on `before_create` with column
   defaults (all scores 10, `armor_class` 10, etc.) rather than
   user-supplied values.[^characters-controller]
2. Initial HP is computed from the class's hit die plus the CONSTITUTION
   modifier — see [models/player-character.md](/models/player-character.md).

# Combat-execution flow

1. **[Combat::Simulator](/architecture/combat-simulator.md)** —
   seeded, repeatable simulation that mixes basic attacks with class-feature
   and spell effects run through
   [the Combat::* pipeline](/architecture/combat-effect-pipeline.md), gated
   by remaining uses, ending in a `victory`/`draw`/`max_rounds_reached`
   outcome.
2. **[Passive effect triggers](/architecture/passive-effect-triggers.md)** —
   `always`/`turn_start`/`turn_end` `effect_payload`s (e.g. Champion's
   improved critical) read directly off `PlayerCharacter`; the simulator
   applies the `turn_start`/`turn_end` ones around each combatant's turn.

Repeated runs are driven by [simulation batches](/architecture/simulation-batches.md):
up to 1000 `Combat::Simulator` combats between two sides, one Solid Queue
job each, run in parallel by worker processes that push progress to the page,
aggregated into win rate, healing and damage metrics.

# Patterns used

- **Delegated types**: `Combatant` uses Rails' `delegated_type :combatable,
  types: %w[ PlayerCharacter ]` (not a raw polymorphic association) so
  entity types other than `PlayerCharacter` can enter combat later without a
  schema change — see [models/combatant.md](/models/combatant.md).
- **Service objects**: complex logic (combat orchestration) lives under
  `app/services/`, separate from models; the level-up service has since
  been removed (see [models/player-character.md](/models/player-character.md)).
- **ERB views**: plain Rails views under `app/views/`, styled with Bootstrap
  — see [ui/erb-bootstrap-views.md](/ui/erb-bootstrap-views.md).

For installing dependencies, running the dev server, and running tests
locally, see [ops/dev-setup.md](/ops/dev-setup.md).

[^characters-controller]: Source: `app/controllers/player_characters_controller.rb`
