---
type: Service
title: CombatSimulatorService — seeded, feature-aware combat orchestrator
description: A new combat orchestrator (parallel to EncounterService) that runs seeded, repeatable encounters combining basic attacks with class-feature effects gated by remaining uses, ending in victory/draw/max-rounds outcomes.
resource: app/services/combat_simulator_service.rb
tags: [combat, evolution]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-06T02:15:00Z
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
- `abort_if`: optional callable checked before every round; when it returns
  true, `call` raises `CombatSimulatorService::Aborted` (used to cancel
  [simulation batches](/architecture/simulation-batches.md)).
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
   A payload with `"applies_to": "weapon_attack"` (every Battle Master
   maneuver) is *not* an action of its own: choosing it makes the turn a normal
   weapon attack, and only if the attack hits is the maneuver's die rolled
   through the same pipeline (doubled on a critical hit) and added as an extra
   damage instance, spending one superiority die — a miss spends nothing. A
   `"debuff": "next_attack_advantage"` (Distracting Strike) also marks the
   target: the first weapon attack against it by anyone other than the marker
   rolls with advantage and uses the mark up, and the mark expires at the start
   of the marker's next turn (`@advantage_marks`). Weapon attacks only; spell
   attacks ignore marks.
   The target is picked at random from the payload's `"target"` kind
   (`self`, `enemy` = opposing party, `ally` = own party): a damage feature or
   spell never lands on the actor or their party, and a heal never on an enemy.
   An unknown kind raises `ArgumentError`; with no valid target left alive
   the target is `nil`, which is why Action Surge's extra action is skipped
   once the fight is already over.
3. **Cast spell** actions are offered for each known [spell](/models/spell.md)
   with an `effect_payload` that is a cantrip or has a spell slot left, via
   `PlayerCharacter#cast_spell`. A payload with `"attack": "spell"` rolls a spell
   attack against the target's AC and a `"dc": "spell"` save uses the caster's spell
   save DC (both from the spellcasting ability, see
   [combat-effect-pipeline.md](/architecture/combat-effect-pipeline.md)); the
   turn's result then carries an `attack_roll` (`natural`, `total`, `armor_class`,
   `hit`, `crit`). Weapon attacks in the log carry `natural`, `total`, `crit` and
   `damage` (inside `attack_roll`) plus the target's `hp_before`/`hp_after` around the hit (before any maneuver rider); both kinds decide the hit with `Dice.hit?` (natural 20 always hits,
   natural 1 always misses), so an auto-hit can show a `total` below the AC.

The available actions are collected into a list and one is picked with
`.sample(random: @rng)` — action choice is random, not strategic — **unless the
actor has at least one enabled [gambit](/models/gambit.md)** (see below).

# Gambits (FFXII-style turn AI)

An actor with enabled gambits never samples: its rules are walked by
`position` (1 first). A rule wins when its action is in `available_actions_for`
(attack always; a feature with uses, a known maneuver, a spell with a slot) and
its condition finds a target among the living combatants of the rule's side
(`self`, `ally` = own party with the actor, `enemy`), **walked in initiative
order** (`@initiative_order`) — `any` takes the first, `hp_below`/`hp_above`
the first strictly under/over X% of max HP, `lowest_hp`/`highest_hp` the
minimum/maximum (ties to initiative order), `marked`/`unmarked` whether the
target carries a Distracting Strike mark from someone else (one the actor would
use), and `resource_at_least` checks the actor's resource for the rule's own
action (feature uses, the superiority-dice pool for maneuvers, slots of the
spell's level) and takes the first candidate. The
chosen target replaces `resolve_feature_target` for features and spells; every
attack of the action re-runs the rule's pick, falling back to the first living
enemy in initiative order. No rule fires → the turn logs `action: { type: :idle }`
with empty `results`. Gambit choices draw nothing from `@rng`, and actors with
no enabled gambit take the old random path unchanged. Rules are loaded once per
simulation and evaluated over `Gambit` objects (saved or not).

**Action Surge** is a gambit action (target Self) for these actors: when its
rule wins, one use is spent, a marker turn `action: { type: :action_surge }` is
logged, and the list is evaluated twice more (the second `extra: true`), skipping
surge rules; either may stand idle, and both stop once the fight is over. A
gambit-driven actor never gets the automatic random surge. **War Magic** stays
automatic after the first of those actions; its bonus attack aims at the spell's
target if it is a living enemy, else the first living enemy in initiative order. Decisions:
[gambits-decisions.md](/architecture/gambits-decisions.md).

# Lookup caching

A character's class, level and choices cannot change mid-combat, so the
lookups the turn loop repeats are loaded once per simulation:
`highest_unlock_per_feature` and the known-maneuver ids are memoized per
combatant on the service instance (one instance per simulation), and
`PlayerCharacter` caches its unlocked feature unlocks, class progression and
spellcasting feature (see [player-character.md](/models/player-character.md)).
This cut a typical simulation from ~259 queries / ~590 ms to ~39 / ~97 ms;
60 seeded results across four compositions were byte-identical before and
after, and a test pins the unlock lookups to one per combatant per side of the
cache.

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
