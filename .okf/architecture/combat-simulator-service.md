---
type: Service
title: CombatSimulatorService — seeded, feature-aware combat orchestrator
description: The official combat orchestrator; runs seeded, repeatable encounters combining basic attacks with class-feature effects gated by remaining uses, ending in victory/draw/max-rounds outcomes.
resource: app/services/combat_simulator_service.rb
tags: [combat, evolution]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-18T00:00:00Z
verified: { by: human:lsolagc, at: 2026-10-11T19:06:20Z }
sources:
  - id: combat-simulator-rb
    title: app/services/combat_simulator_service.rb
    resource: ../../app/services/combat_simulator_service.rb
  - id: combat-simulator-test
    title: test/services/combat_simulator_service_test.rb
    resource: ../../test/services/combat_simulator_service_test.rb
  - id: feature-book-rb
    title: app/services/combat/feature_book.rb
    resource: ../../app/services/combat/feature_book.rb
status: stable
---

# Overview

`CombatSimulatorService` is the project's **single, official** combat
orchestrator (the legacy `EncounterService` was removed on 2026-10-11). It is
where basic attacks and
[the Combat::* effect pipeline](/architecture/combat-effect-pipeline.md)
run side by side in the same turn loop, each combatant picking one action
per turn (see
[combat-migration-strategy.md](/architecture/combat-migration-strategy.md)
for why it became the official orchestrator and what Phases 2 and 3 still
owe it).[^combat-simulator-rb]

It is **seedable** — `Random.new(seed)` drives
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
#   initiative: [ { actor_id: 7, natural: 14, total: 16 }, ... ], # in the order they act
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
combatant.initiative)`, one roll per combatant in party order, tie-broken by
that order), gets **one** action per turn. The rolls go to the result's
`initiative` (`actor_id`, `natural`, `total`), in the order the combatants act;
recording them draws nothing extra. Turn results carry no human-readable
`message` (removed 2026-10-17: the structured fields already say it all):

1. **Attack** is always available: a `Combat::CombatAction(source_type:
   :attack)` run by `Combat::ActionRunner.attack`, which makes
   `attacks_per_action` weapon attacks (War Magic's bonus: exactly one) and asks `execute_attack_action` for
   each attack's target (a random living enemy, the gambit's target, or War
   Magic's focus), so an attack after a kill goes to someone else. See
   [combat-action-language.md](/architecture/combat-action-language.md).
2. **Class feature** actions are offered for every unlocked feature whose
   `effect_payload.kind` is `heal` or `damage`, has no `trigger` (i.e. is
   *not* one of the [passive triggers](/architecture/passive-effect-triggers.md)),
   and still has uses remaining; the feature is run through
   `Combat::CombatAction` + `Combat::ActionRunner`, exactly like
   [PlayerCharacter#cast_spell](/models/spell.md) does for spells.
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

**Turn objects.** Each offered action is a `Combat::ActionOption` (an immutable
`Data`: `type`, `class_feature`, `spell`, `payload`, `uses_remaining`, and
`target`/`gambit` once a gambit picks it, through `#with`; predicates
`chosen_by_gambit?`, `spell?`, `maneuver?`, `action_surge?`). It compares by
value, as the hashes it replaced did, so the list arithmetic and `sample` draw
the same. Each logged entry is a `Combat::TurnRecord` (`round`, `turn`,
`actor_id`, `actor_name`, `actor_party`, `action`, `results`, `gambit`, `extra`,
`bonus`), its header built in `TurnRecord.for`; the loop turns each round's
records into hashes (`#to_h`) as it appends them to `round_log`, always in that
key order and without `gambit` when nil and `extra`/`bonus` when false. The `action` inside
and the effects in `results` are still hashes.

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
no enabled gambit take the old random path unchanged. Open:
[issue #40](https://github.com/lsolagc/dnd5ecombatsimulator/issues/40) makes
`any` pick a random target and merges the dice RNG (`srand`) and `@rng` into
one stream. Rules are loaded once per
simulation and evaluated over `Gambit` objects (saved or not).

**Log.** `gambits:` (optional, a batch's `gambit_settings`) makes the
simulation run and log from that copy, rebuilding unsaved `Gambit`s. The result
does not list the rules: a batch's log lists them once in its header, from the
same copy, through `Gambit.log_section` (per combatant `mode`, `"gambits"` or
`"aleatório"` with no enabled rule, and every rule by priority: position,
enabled, target, condition, action, rule; see
[simulation-batches.md](/architecture/simulation-batches.md)). Every decision entry carries `gambit`: `{ position, rule }`,
`"nenhum aplicável: parado"` or `"aleatório"` (random choice and the automatic
Action Surge); the War Magic bonus inherits its spell's, passives carry none.

**Action Surge** is a gambit action (target Self) for these actors: when its
rule wins, one use is spent, a marker turn `action: { type: :action_surge }` is
logged, and the list is evaluated twice more (the second `extra: true`), skipping
surge rules; either may stand idle, and both stop once the fight is over. A
gambit-driven actor never gets the automatic random surge. **War Magic** stays
automatic after the first of those actions; its bonus is exactly one weapon attack (not the
Attack action, so no Extra Attack; since 2026-10-18, see the
[impact report](/architecture/war-magic-impact.md)) and aims at the spell's
target if it is a living enemy, else the first living enemy in initiative order. Decisions:
[gambits-decisions.md](/architecture/gambits-decisions.md).

# Feature book

What a combatant knows how to do is read from one `Combat::FeatureBook` per
combatant, built in `initialize_state` and kept by combatant id
(`feature_book(combatant)`); the simulator no longer walks unlocks or compares
feature names.[^feature-book-rb] It is read-only and holds no counters:

| Query | Answers |
|---|---|
| `unlocks` | the unlocks in force (`PlayerCharacter#feature_unlocks`) |
| `action_payload(feature)` | the feature's action effect (`PlayerCharacter#action_payload`), nil when not unlocked, not an action at the level, or a maneuver the character has not learned |
| `unlock_with(kind)` | the unlock in force of the feature whose effect is `extra_action` (Action Surge) or `reroll_save` (Indomitable), or nil |
| `weapon_attacks_after(spell)` | how many bonus weapon attacks (a `grants_activity`'s `count`, one) follow this spell: `after.cast_with_action` `cantrip` (War Magic) only after a cantrip, `any_spell` (Improved War Magic) after any; nil for none |
| `rider?(on:, applies:)` | a hit leaves the Eldritch Strike mark (`rider`, `on: weapon_hit`, `applies: disadvantage_on_next_save`) |
| `resource_feature_id(feature)` | whose uses the feature spends: the `resource_pool`'s (Combat Superiority) for a maneuver, else its own |
| `initial_uses` | `{ class_feature_id => uses }` at the start of combat (see Resource tracking) |

It recognises these features by the `kind` of their effect at the character's
level (`PlayerCharacter#effect_payloads`; the vocabulary is
[ClassFeatureUnlock](/models/class-feature-unlock.md)'s `EFFECT_KINDS`), never by
name: renamed, every seed replays its golden file (phase 5.2). The book delegates to the character's cached lookups;
its only state is the known-maneuver ids, read on the first maneuver it is asked
about. No queries or RNG draws were added (golden files and query ceiling
unchanged). It takes a `PlayerCharacter`; another kind of combatant gets its
own way of building one when it arrives.

# Lookup caching

A character's class, level and choices cannot change mid-combat, so the
lookups the turn loop repeats are loaded once per simulation:
the known-maneuver ids are memoized in each combatant's feature book
(one per simulation), and `PlayerCharacter` caches its feature
unlocks (`#feature_unlocks`, the simulator's only unlock lookup), class
progression and spellcasting feature (see [player-character.md](/models/player-character.md)).
This cut a typical simulation from ~259 queries / ~590 ms to ~39 / ~97 ms;
60 seeded results across four compositions were byte-identical before and
after, and a test pins the unlock lookups to one per combatant per side of the
cache.

# Resource tracking

At encounter start, each combatant's usable features get an initial use
count (`FeatureBook#initial_uses`): a fixed `unlock.uses` if present, otherwise
`unlock.uses_formula` resolved through `Combat::RollExpression`/`Combat::RollContext`
and floored — e.g. a formula of `proficiency_bonus` becomes an
integer use count. The simulator keeps the counts left in `@uses_remaining`
(they move to `Combat::Participant` in phase 3.3). Each class-feature action decrements the actor's
remaining uses for that feature by 1, floored at 0
(`consume_feature_use!`); once exhausted, that action stops being offered.

# Outcome

- **`:draw`** — both parties have zero living combatants after a round
  (simultaneous elimination); `winning_party` is `nil`.
- **`:victory`** — exactly one party has a living combatant when the loop
  ends.
- **`:max_rounds_reached`** — the loop hit `max_rounds` with no winner and
  no draw.

[^combat-simulator-rb]: Source: `app/services/combat_simulator_service.rb`

[^combat-simulator-test]: Source: `test/services/combat_simulator_service_test.rb`

[^feature-book-rb]: Source: `app/services/combat/feature_book.rb`
