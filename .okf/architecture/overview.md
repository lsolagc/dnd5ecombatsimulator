---
type: Overview
title: System Architecture Overview
description: High-level layering of the D&D 5e combat simulator — presentation, services, models, and database — and how a character-creation or combat request flows through them.
tags: [rails]
generated:
  by: copilot-cli/claude-sonnet-5
  at: 2026-08-21T23:39:26Z
sources:
  - id: characters-controller
    title: app/controllers/player_characters_controller.rb
    resource: ../../app/controllers/player_characters_controller.rb
---

# Overview

The D&D Combat Simulator is a Rails 8 application for managing D&D 5e
characters and classes, and for simulating combat encounters between teams to
measure win rate, encounter duration, and the impact of specific mechanics.

It is layered as: a presentation layer (controllers + Phlex view components),
a business-logic layer (services + validators), a persistence layer
(ActiveRecord models), and a database (SQLite in development, with PostgreSQL
support).

Three combat systems coexist and are **not** interchangeable — see
[encounter-service.md](/architecture/encounter-service.md) (the frozen
legacy flow), [combat-effect-pipeline.md](/architecture/combat-effect-pipeline.md)
(the pipeline new mechanics should target),
[combat-simulator-service.md](/architecture/combat-simulator-service.md)
(a newer orchestrator combining the two), and
[passive-effect-triggers.md](/architecture/passive-effect-triggers.md) (a
fourth, data-driven mechanism running independently of any orchestrator).
Any task touching combat should first identify which of these it affects.

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

Two separate orchestrators exist, and a third data-driven mechanism runs
alongside both:

1. **[EncounterService](/architecture/encounter-service.md)** (frozen,
   legacy) — `EncounterService.new(party_one:, party_two:).call` rolls
   initiative, loops rounds of basic attacks, and exposes an
   `encounter_log`.
2. **[CombatSimulatorService](/architecture/combat-simulator-service.md)**
   (newer, separate) — seeded, repeatable simulation that mixes basic
   attacks with class-feature effects run through
   [the Combat::* pipeline](/architecture/combat-effect-pipeline.md), gated
   by remaining uses, ending in a `victory`/`draw`/`max_rounds_reached`
   outcome.
3. **[Passive effect triggers](/architecture/passive-effect-triggers.md)** —
   `always`/`turn_start`/`turn_end` `effect_payload`s (e.g. Champion's
   improved critical) read directly off `PlayerCharacter`, independent of
   either orchestrator above — and not yet actually invoked by either one's
   turn loop.

Any task touching combat should first identify which of these three it
affects — they are not interchangeable, and none of them defers to another.

# Patterns used

- **Delegated types**: `Combatant` uses Rails' `delegated_type :combatable,
  types: %w[ PlayerCharacter ]` (not a raw polymorphic association) so
  entity types other than `PlayerCharacter` can enter combat later without a
  schema change — see [models/combatant.md](/models/combatant.md).
- **Service objects**: complex logic (combat orchestration) lives under
  `app/services/`, separate from models; the level-up service has since
  been removed (see [models/player-character.md](/models/player-character.md)).
- **Phlex view components**: views are reusable Ruby components under
  `app/components/` — see [ui/phlex-components.md](/ui/phlex-components.md).

For installing dependencies, running the dev server, and running tests
locally, see [ops/dev-setup.md](/ops/dev-setup.md).
