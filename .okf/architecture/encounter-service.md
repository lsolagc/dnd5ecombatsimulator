---
type: Service
title: EncounterService — legacy combat orchestrator
description: The current combat-encounter orchestrator (initiative, rounds, attacks, damage); intentionally frozen and treated as provisional pending the Combat::* pipeline migration.
resource: app/services/encounter_service.rb
tags: [combat, frozen]
generated:
  by: copilot-cli/claude-sonnet-5
  at: 2026-08-21T23:39:26Z
sources:
  - id: encounter-service-rb
    title: app/services/encounter_service.rb
    resource: ../../app/services/encounter_service.rb
status: stable
---

# Overview

`EncounterService` orchestrates a full combat encounter between two teams of
combatants: it rolls initiative (d20 + DEX modifier), runs rounds where each
combatant attacks in initiative order, applies damage, and stops once one
team is entirely dead.[^encounter-service-rb]

**This service is frozen by explicit project convention**: it must be treated
as a provisional, intentionally simple implementation and must not be expanded
or restructured outside of an explicit combat-system refactor. It is strongly
coupled to the current data model, so structural changes here tend to force
changes elsewhere. New mechanics should instead target
[combat-effect-pipeline.md](/architecture/combat-effect-pipeline.md); the
phased plan for introducing that pipeline alongside this frozen service is in
[combat-migration-strategy.md](/architecture/combat-migration-strategy.md).
[CombatSimulatorService](/architecture/combat-simulator-service.md) is a
separate, newer orchestrator that already combines attacks with class
features — it does not touch this service.

**Note**: this concept previously drifted from an earlier project
documentation description of `EncounterService` (which predated the current
implementation and has since been removed from the repo) — this concept
reflects the actual current code, not that prior description.

# Contract

```ruby
encounter = EncounterService.new(party_one:, party_two:, reset_hit_points: true)
encounter.call            # => self
encounter.encounter_log   # => { rounds: { 1 => [...], ... }, end_of_encounter: { winner:, number_of_rounds: } }
```

- `party_one` / `party_two`: non-empty arrays of combatants (e.g.
  `PlayerCharacter`); raises `ArgumentError` otherwise.
- `reset_hit_points` (default `true`): when true, sets every combatant's
  `current_hit_points` to `max_hit_points` before rolling initiative.
- `call` returns **`self`**, not a result hash — callers read
  `encounter_log` afterward. There is no `{ rounds:, winner:, events: }`
  hash as such; `encounter_log[:rounds]` is a hash keyed by round number,
  and `encounter_log[:end_of_encounter]` carries `winner` (an array of
  combatant names, or `["No winner"]` if neither side is fully dead when the
  loop ends) and `number_of_rounds`.
- Initiative uses `Dice.d20(modifier: combatant.initiative)` — `initiative`
  is the combatant's DEX modifier (see
  [combatant.md](/models/combatant.md)) — ordered highest-first, ties kept
  in rolled order.
- Each combatant attacks `attacks_per_action` times per turn (falls back to
  1 if the combatant does not respond to `attacks_per_action`), each attack
  picking a random living enemy.

# Attack resolution

Attacks and damage go through the same `PlayerCharacter#roll_an_attack` /
`#get_attacked` / `#take_damage` path described in
[player-character.md](/models/player-character.md): a `Dice::AttackRoll`
built from a fixed `"1d4"` damage die, STR modifier, and
`critical_hit_threshold`, compared against `armor_class`; a hit always
applies `damage_type: :bludgeoning` (weapon typing is not yet modeled),
adjusted by the target's resistance/immunity/vulnerability.[^encounter-service-rb]
