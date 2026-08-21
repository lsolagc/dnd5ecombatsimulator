---
type: Service
title: CombatSimulatorService — seeded, feature-aware combat orchestrator
description: A new combat orchestrator (parallel to EncounterService) that runs seeded, repeatable encounters combining basic attacks with class-feature effects gated by remaining uses, ending in victory/draw/max-rounds outcomes.
resource: app/services/combat_simulator_service.rb
tags: [combat, evolution]
generated:
  by: copilot-cli/claude-sonnet-5
  at: 2026-08-21T23:15:00Z
sources:
  - id: combat-simulator-rb
    title: app/services/combat_simulator_service.rb
    resource: ../../app/services/combat_simulator_service.rb
  - id: combat-simulator-test
    title: test/services/combat_simulator_service_test.rb
    resource: ../../test/services/combat_simulator_service_test.rb
status: stable
---

# Overview

`CombatSimulatorService` is a **new, separate** combat orchestrator — it does
not modify or replace the frozen
[EncounterService](/architecture/encounter-service.md), and it is the first
concrete place in the codebase where basic attacks and
[the Combat::* effect pipeline](/architecture/combat-effect-pipeline.md)
run side by side in the same turn loop, one of two possible actions per
combatant per turn (see
[combat-migration-strategy.md](/architecture/combat-migration-strategy.md)
for how this relates to the planned phased migration).[^combat-simulator-rb]

Unlike `EncounterService`, it is **seedable** — `Random.new(seed)` drives
every roll and every `sample`, and the same seed reproduces an identical
`round_log` and outcome, which is what makes it useful for measuring win
rate and mechanic impact across repeated simulations rather than a single
playthrough.[^combat-simulator-test]

# Contract

```ruby
result = CombatSimulatorService.new(
  party_one:, party_two:, seed: 1234, max_rounds: 20
).call
# => {
#   winning_party: :party_one | :party_two | nil,
#   total_rounds: 6,
#   round_log: [ { round: 1, turns: [ {...} ] }, ... ],
#   draw: false,
#   outcome: :victory | :draw | :max_rounds_reached
# }
```

- `party_one` / `party_two`: non-empty arrays of combatants; raises
  `ArgumentError` otherwise.
- `seed`: optional; when given, both the instance RNG and the global
  `Random` seed (via `Random.srand`, restored after `call`) are pinned, so
  every dice roll — including inside `Combat::RollExpression` — is
  reproducible.
- `max_rounds`: default 20; the loop stops early once one party has no
  combatants left alive (`combat_over?`).

# Turn resolution

Each living combatant, in initiative order (`Dice.d20(modifier:
combatant.initiative)`, tie-broken by original array order), gets **one**
action per turn:

1. **Attack** is always available and repeats `attacks_per_action` times
   against a random living enemy, using the same
   `roll_an_attack`/`get_attacked` pair
   [EncounterService](/architecture/encounter-service.md) uses.
2. **Class feature** actions are offered for every unlocked feature whose
   `effect_payload.kind` is `heal` or `damage`, has no `trigger` (i.e. is
   *not* one of the [passive triggers](/architecture/passive-effect-triggers.md)),
   and still has uses remaining; the feature is run through
   `Combat::CombatAction` + `Combat::ActionRunner`, exactly like
   [PlayerCharacter#use_class_feature](/models/player-character.md).

The available actions are collected into a list and one is picked with
`.sample(random: @rng)` — action choice is random, not strategic.

# Resource tracking

At encounter start, each combatant's usable features get an initial use
count: a fixed `unlock.uses` if present, otherwise `unlock.uses_formula`
resolved through `Combat::RollExpression`/`Combat::RollContext` and floored
(`normalize_uses_value`) — e.g. a formula of `proficiency_bonus` becomes an
integer use count. Each class-feature action decrements the actor's
remaining uses for that feature by 1, floored at 0
(`consume_feature_use!`); once exhausted, that action stops being offered.

# Outcome

- **`:draw`** — both parties have zero living combatants after a round
  (simultaneous elimination); `winning_party` is `nil`.
- **`:victory`** — exactly one party has a living combatant when the loop
  ends.
- **`:max_rounds_reached`** — the loop hit `max_rounds` with no winner and
  no draw.
