---
type: Service
title: Combat::Simulator — seeded, feature-aware combat orchestrator (with GambitPolicy and TurnExecutor)
description: The official combat orchestrator, split in three objects (Simulator, GambitPolicy, TurnExecutor); runs seeded, repeatable encounters combining basic attacks with class-feature effects gated by remaining uses, ending in victory/draw/max-rounds outcomes.
resource: app/services/combat/simulator.rb
tags: [combat, evolution]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T00:00:00Z
verified: { by: human:lsolagc, at: 2026-10-11T19:06:20Z }
sources:
  - id: combat-simulator-rb
    title: app/services/combat/simulator.rb
    resource: ../../app/services/combat/simulator.rb
  - id: gambit-policy-rb
    title: app/services/combat/gambit_policy.rb
    resource: ../../app/services/combat/gambit_policy.rb
  - id: turn-executor-rb
    title: app/services/combat/turn_executor.rb
    resource: ../../app/services/combat/turn_executor.rb
  - id: combat-simulator-test
    title: test/services/combat/simulator_test.rb
    resource: ../../test/services/combat/simulator_test.rb
  - id: feature-book-rb
    title: app/services/combat/feature_book.rb
    resource: ../../app/services/combat/feature_book.rb
  - id: participant-rb
    title: app/services/combat/participant.rb
    resource: ../../app/services/combat/participant.rb
  - id: encounter-rb
    title: app/services/combat/encounter.rb
    resource: ../../app/services/combat/encounter.rb
  - id: status-rb
    title: app/services/combat/status.rb
    resource: ../../app/services/combat/status.rb
status: stable
---

# Overview

`Combat::Simulator` is the project's **single, official** combat
orchestrator (the legacy `EncounterService` was removed on 2026-10-11; until
phase 3.5 of the DDD refactor, 2026-10-19, it was one class,
`CombatSimulatorService`). It is
where basic attacks and
[the Combat::* effect pipeline](/architecture/combat-effect-pipeline.md)
run side by side in the same turn loop, each combatant picking one action
per turn (see
[combat-migration-strategy.md](/architecture/combat-migration-strategy.md)
for why it became the official orchestrator and what Phases 2 and 3 still
owe it).[^combat-simulator-rb]

It is **seedable** — `Random.new(seed)` drives
every random pick and `Random.srand(seed)` every dice roll, and the same seed reproduces an identical
`round_log` and outcome, which is what makes it useful for measuring win
rate and mechanic impact across repeated simulations rather than a single
playthrough.[^combat-simulator-test]

# Structure

Three objects since phase 3.5 (decisions D1–D5, approved 2026-10-19), all in
`app/services/combat/`:

| Object | Owns | Public API |
|---|---|---|
| `Combat::Simulator`[^combat-simulator-rb] | the fight as a whole: the seed (`with_seed`), the `Encounter` and its participants (built in party order), initiative, the round loop, each turn's start (`Encounter#start_turn`, skipping the dead) and turn passives (`turn_start`/`turn_end`), the result | `new(...)`, `#call` (with an optional block, see Contract), `#encounter`, `#rng`, `Aborted`, `DEFAULT_MAX_ROUNDS` |
| `Combat::GambitPolicy`[^gambit-policy-rb] | the gambit-driven choice, one per simulation; never draws from any RNG | `#rules_for(actor)` (enabled rules by position, loaded once: the actor's own or the `gambits:` copy's), `#choose(actor:, options:, surging: false)` (the winning `ActionOption` with its target and gambit, Action Surge included, or nil), `#target(actor:, gambit:)` (the criteria), `#log(gambit)` (`{ position:, rule: }`, the copy's label when it has one) |
| `Combat::TurnExecutor`[^turn-executor-rb] | one actor's decisions in a turn, with the encounter, the simulator's RNG and the policy: gambits or the random choice (the coin flip between physical and spell options stays here: no RandomPolicy), Action Surge (by rule or at random), War Magic, and running the actions through the pipeline into `TurnRecord`s | `#take_turn(actor, round:, turn:)` (the turn's decision entries, passives aside), `#run(actor:, option:, round:, turn:)` (one chosen option, without its gambit), `#war_magic_turn`, `#action_surge_turn`, `#choose_at_random(actor:, options:)`, `#random_target(actor:, payload:)`; `RANDOM_GAMBIT`, `IDLE_GAMBIT` |

What an actor can do this turn is `Combat::Participant#action_options` (see
Participant); how an effect result is logged is
`Combat::TurnRecord.serialize_results`. The simulator builds the executor and
the policy once per `#call`, after the encounter. Same RNG draws, golden
files, queries and time as the single class it replaced (see
[combat-regression.md](/ops/combat-regression.md)).

# Contract

```ruby
result = Combat::Simulator.new(
  party_one:, party_two:, seed: 1234, max_rounds: 20,
  hit_points: { 7 => 9 }, gambits: nil, abort_if: nil # all optional
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

- `party_one` / `party_two`: non-empty arrays of character sheets
  (`PlayerCharacter`); raises `ArgumentError` otherwise. Each fights as a
  `Combat::Participant` (see below) and the sheets are only read. The result's
  ids (`initiative[].actor_id`, each turn's `actor_id`, an attack's `target_id`)
  are **combatant ids**, `Combat::Participant#id` = `sheet.combatant.id`, never
  the sheet's (since phase 5.1, 2026-10-31: a `PlayerCharacter` and a Monster
  can share an id).
- `hit_points`: optional starting HP, `{ combatant id => HP }` (a
  [batch](/architecture/simulation-batches.md)'s `current_hit_points`
  settings); a combatant left out starts at its `max_hit_points`.
- `seed`: optional; when given, both the instance RNG and the global
  `Random` seed (via `Random.srand`, restored after `call`) are pinned, so
  every dice roll — including inside `Combat::RollExpression` — is
  reproducible.
- `abort_if`: optional callable checked before every round; when it returns
  true, `call` raises `Combat::Simulator::Aborted` (used to cancel
  [simulation batches](/architecture/simulation-batches.md)).
- `max_rounds`: default 20; the loop stops early once one party has no
  combatants left alive (`Combat::Encounter#over?`).
- `gambits`: optional copy of the rules the simulation runs and logs from
  instead of each combatant's own, keyed by combatant id (see Gambits, Log).
- A block given to `call` gets the encounter once initiative is rolled, before
  the first round, inside the seed: a test sets statuses or the initiative
  order there. After `call`, `#encounter` holds the participants as they
  ended and `#rng` the random-choice RNG (the tests check what it drew).
- One fight per instance: a second `call` builds new participants but goes on
  with the first one's `rng` and appends to its `round_log`.

# Turn resolution

Each living combatant, in initiative order (`Dice.d20(modifier:
combatant.initiative)`, one roll per combatant in party order, tie-broken by
that order), gets **one** action per turn. The rolls go to the result's
`initiative` (`actor_id`, `natural`, `total`), in the order the combatants act;
recording them draws nothing extra. Turn results carry no human-readable
`message` (removed 2026-10-17: the structured fields already say it all):

1. **Attack** is always available: a `Combat::CombatAction(source_type:
   :attack)` run by `Combat::ActionRunner.attack`, which makes
   `attacks_per_action` weapon attacks (War Magic's bonus: exactly one) and asks the turn executor for
   each attack's target (a random living enemy, the gambit's target, or War
   Magic's focus), so an attack after a kill goes to someone else. See
   [combat-action-language.md](/architecture/combat-action-language.md).
2. **Class feature** actions are offered for every unlocked feature whose
   `effect_payload.kind` is `heal` or `damage`, has no `trigger` (i.e. is
   *not* one of the [passive triggers](/architecture/passive-effect-triggers.md)),
   and still has uses remaining; the feature is run through
   `Combat::CombatAction` + `Combat::ActionRunner`, exactly like
   `Combat::Participant#cast_spell` does for [spells](/models/spell.md).
   A payload with `"applies_to": "weapon_attack"` (every Battle Master
   maneuver) is *not* an action of its own: choosing it makes the turn a normal
   weapon attack, and only if the attack hits is the maneuver's die rolled
   through the same pipeline (twice the dice on a critical hit) and added as an extra
   damage instance, spending one superiority die — a miss spends nothing. Each
   item of the payload's `"statuses"` is then applied to the target as a
   `Combat::Status` (see Statuses below): Distracting Strike's
   `next_attack_advantage`, `ends: source_turn_start`.
   Both are **riders** ([glossary](/ubiquitous-language.md)), logged as
   `Combat::Rider#to_h`:[^rider-rb] the attack action lists the riders chosen
   for it (`action: { type: :attack, riders: [ { feature_slug, feature_name } ] }`,
   no `riders` key when none was chosen), kept even when every attack misses; each
   attack lists the riders it applied in `riders`, always present and empty on a
   miss. An applied rider is `{ feature_slug, feature_name }`, then its effect's
   keys when it has one (`kind`, `applied`, `amount`, `hp_before`, `hp_after`,
   `roll_outcome`: the maneuver's die), then `statuses` when it applied any (only
   the kinds: the maneuver's `statuses`, Eldritch Strike's
   `disadvantage_on_next_save`). The order of several riders on one attack is not
   settled yet: no combatant has both.
   The target is picked at random from the payload's `"target"` kind
   (`self`, `enemy` = opposing party, `ally` = own party): a damage feature or
   spell never lands on the actor or their party, and a heal never on an enemy.
   An unknown kind raises `ArgumentError`; with no valid target left alive
   the target is `nil`, which is why Action Surge's extra action is skipped
   once the fight is already over.
3. **Cast spell** actions are offered for each known [spell](/models/spell.md)
   with an `effect_payload` that is a cantrip or has a spell slot left, via
   `Combat::Participant#cast_spell`. A payload with `"attack": "spell"` rolls a spell
   attack against the target's AC and a `"dc": "spell"` save uses the caster's spell
   save DC (both from the spellcasting ability, see
   [combat-effect-pipeline.md](/architecture/combat-effect-pipeline.md)); the
   turn's result then carries an `attack_roll` (`natural`, `total`, `armor_class`,
   `hit`, `crit`). A weapon attack logs the same `attack_roll` (`armor_class` is the
   target's effective AC: the sheet's final AC, Fighting Style: Defense in it) and its damage as an
   effect does: `{ kind: :attack, target_id, target_name, advantage, riders, amount,
   hp_before, hp_after, roll_outcome, attack_roll }`, `amount` 0 on a miss and
   `hp_before`/`hp_after` around the hit (before any maneuver rider); no `applied`,
   `success` or `damage`, which repeated `attack_roll.hit` and `amount`. Both kinds
   decide the hit with `Dice.hit?` (natural 20 always hits, natural 1 always misses),
   so an auto-hit can show a `total` below the AC. Every `roll_outcome` lists the
   dice as rolled (`dice: ["2d10"]` for a critical `1d10`) and one value per die in
   `rolls` (see [combat-effect-pipeline.md](/architecture/combat-effect-pipeline.md)).

The available actions are collected into a list and one is picked with
`.sample(random: rng)` (`TurnExecutor#choose_at_random`) — action choice is random, not strategic — **unless the
actor has at least one enabled [gambit](/models/gambit.md)** (see below).
This turn AI is deliberately primitive: a spellcaster with at least one castable
spell first flips a coin (`rng.rand < 0.5`) between the physical options (attack
and class features) and the spell options, then samples uniformly inside the
branch; a non-caster, or a caster with nothing castable right now, samples
uniformly over everything with no coin, so the RNG draws of most actors are the
ones they had before the coin existed. Right after that action come War Magic's
bonus attack, when the spell grants one, and then, with an unused Action Surge,
one extra action drawn uniformly from all its options (no caster coin) that spends a use (`#action_surge_turn`, nil once the
fight is over). Neither recurses: the extra action never grants another surge or
a War Magic bonus, and a plain attack never grants a bonus attack.

**Turn objects.** Each offered action is a `Combat::ActionOption` (an immutable
`Data`: `type`, one of `:attack`, `:class_feature` (a maneuver included),
`:cast_spell` and `:action_surge` (offered only to the gambit policy, from
`Participant#action_surge_option`); `class_feature` for `:class_feature` and
`:action_surge`; `spell` for `:cast_spell`; `payload`, the feature's action
payload at the actor's level or the spell's `effect_payload`;
`uses_remaining`, the uses left of the resource it spends (a maneuver's is the
superiority-dice pool), nil for a spell or an unlimited feature; and
`target`/`gambit` once a gambit picks it, through `#with`; predicates
`chosen_by_gambit?`, `spell?`, `maneuver?`, `action_surge?`). It compares by
value, as the hashes it replaced did, so the list arithmetic and `sample` draw
the same. Each logged entry is a `Combat::TurnRecord` (`round`, `turn`,
`actor_id`, `actor_name`, `actor_party`, `action`, `results`, `gambit`, `extra`,
`bonus`), its header built in `TurnRecord.for`; the loop turns each round's
records into hashes (`#to_h`) as it appends them to `round_log`, always in that
key order and without `gambit` when nil and `extra`/`bonus` when false (`extra`
marks Action Surge's extra action, `bonus` War Magic's attack; a turn passive has
no `gambit`). The `action` inside
and the effects in `results` are still hashes.

# Gambits (FFXII-style turn AI)

An actor with enabled gambits never samples: its rules are walked by
`position` (1 first). A rule wins when its action is in `Participant#action_options`
(attack always; a feature with uses, a known maneuver, a spell with a slot) and
its condition finds a target among the living combatants of the rule's side
(`self`, `ally` = own party with the actor, `enemy`), **walked in initiative
order** (`Combat::Encounter#initiative_order`) — `any` takes the first, `hp_below`/`hp_above`
the first strictly under/over X% of max HP, `lowest_hp`/`highest_hp` the
minimum/maximum (ties to initiative order), `marked`/`unmarked` whether the
target carries a `next_attack_advantage` status from someone else (one the actor
would use: `Participant#status?(kind, not_from: actor)`), and `resource_at_least` checks the actor's resource for the rule's own
action (feature uses, the superiority-dice pool for maneuvers, slots of the
spell's level) and takes the first candidate. The
chosen target replaces `TurnExecutor#random_target` for features and spells; every
attack of the action re-runs the rule's pick, falling back to the first living
enemy in initiative order. No rule fires → the turn logs `action: { type: :idle }`
with empty `results`. Gambit choices draw nothing from the simulator's `rng`, and actors with
no enabled gambit take the old random path unchanged. Open:
[issue #40](https://github.com/lsolagc/dnd5ecombatsimulator/issues/40) makes
`any` pick a random target and merges the dice RNG (`srand`) and the choice `rng` into
one stream. Rules are loaded once per
simulation and evaluated over `Gambit` objects (saved or not).

**Log.** `gambits:` (optional, a batch's `gambit_settings`, `{ combatant id (string) => [Gambit#snapshot, ...] }`) makes the
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

# Encounter

The fight as a whole is one `Combat::Encounter` (phase 3.4 of the DDD
refactor), built in `Simulator#call` from the two parties of participants;
`call` sets its `initiative_order` once initiative is rolled (party order
before that).[^encounter-rb] The simulator asks it every side question and
keeps none of that state itself:

| Query | Answers |
|---|---|
| `party_one`, `party_two`, `participants` | the parties, and both in party order (the initiative rolls' order) |
| `party_for(participant)` | `:party_one` or `:party_two` (the log's `actor_party`) |
| `allies_of(participant)`, `enemies_of(participant)` | its own party (itself included), the other one |
| `alive(party)`, `first_living_enemy(participant)` | who is standing; the first living enemy in initiative order (War Magic's and a gambit's fallback) |
| `over?` | a party has no one standing |
| `start_turn(actor)` | called at the top of every turn, before the dead actor is skipped: expires on every participant the statuses the actor applied with `ends: source_turn_start` |

# Statuses

A status is a `Combat::Status` (`kind`, `source`: the participant who applied
it, `ends`), carried by the participant it is on.[^status-rb] `kind` comes from
`Combat::Status::KINDS`, the one vocabulary that
[ClassFeatureUnlock](/models/class-feature-unlock.md) also validates the
`rider`'s `applies` and a maneuver's `statuses` against; `ends` is
`source_turn_start` or nil (only used up). A carrier holds **at most one per
kind and source**: the same source applying it again renews it
(`Participant#add_status`). Two kinds:

- `next_attack_advantage` (Distracting Strike, `ends: source_turn_start`): the
  first weapon attack against the carrier by anyone other than a source rolls
  with advantage and uses up **every** such mark that applies to that attacker
  (`take_statuses(kind, not_from: attacker)`), since advantage does not stack
  (5e): marks from two Battle Masters give one attack advantage once. The
  attacker's own mark stays. Weapon attacks only; spell attacks ignore marks.
  Weapon attacks have no disadvantage yet (issue #48), so nothing cancels it.
- `disadvantage_on_next_save` (Eldritch Strike, applied on every hit by a
  feature whose `rider` `applies` it, no end of its own; 5e ends it at the end
  of the attacker's next turn, [issue #50](https://github.com/lsolagc/dnd5ecombatsimulator/issues/50)): the next spell the source
  casts at the carrier **that calls for a save** uses up the source's own status
  (`take_statuses(kind, from: caster)`) and that save has disadvantage; a spell
  attack such as Fire Bolt leaves it in place (since 2026-10-19, see
  [eldritch-strike-save-impact.md](/architecture/eldritch-strike-save-impact.md)). Each attacker keeps its own: a second Eldritch Knight's hit no
  longer erases the first's.

Same RNG draws, golden files, queries and impact metrics (200 seeds per composition) as before the move;
the old `@advantage_marks` and `@eldritch_strike_pending` are gone.

# Participant

Who fights is a `Combat::Participant`, one per sheet, built in
`Simulator#call` in party order (phase 3.3 of the DDD refactor); the party
arrays, the initiative order, gambit and feature targets and the pipeline
(`Combat::EffectExecutor`, `EffectResolver`, `RollContext`, `SavingThrow`,
`ActionRunner`, `TurnRecord`) all work on participants.[^participant-rb] It
owns what changes during the fight, and nothing writes the sheet:

| State | API |
|---|---|
| current HP | `current_hit_points`, `dead?`, `take_damage(amount:, damage_type:)` (after `defenses.apply`, floored at 0), `heal(amount)` (capped at the maximum) |
| spell slots left | `available_spell_slots` (from `PlayerCharacter#spell_slots`), `cast_spell(spell, targets:, disadvantage_on_save:)` (spends a slot of the spell's level, none for a cantrip) |
| uses left | `uses_left(class_feature_id)` (nil: unlimited), `spend_use!(class_feature_id)` (floored at 0), from `FeatureBook#initial_uses` |
| turn passives | `apply_turn_passives!(trigger:)` (see [passive-effect-triggers.md](/architecture/passive-effect-triggers.md)) |
| statuses it carries | `statuses`, `add_status(status)` (renews one of the same kind and source), `take_statuses(kind, not_from:, from:)` (removes and returns them), `status?(kind, not_from:, from:)`, `expire_statuses!(source:)` (see Statuses) |
| what it can do | `feature_book`; `action_options`: this turn's `ActionOption`s, in a fixed order (a seed's pick depends on it) — the Attack action, each unlocked action feature with a use left (a known maneuver included), each spell with an `effect_payload` that is a cantrip or has a slot of its level left (moved from the simulator in phase 3.5); `action_surge_option`: Action Surge as an option when unlocked with a use left, for the policy's gambit action and the executor's random surge |

Everything else it reads from the sheet through one explicit `delegate` list,
the contract a future Monster has to meet: `id`, `name`, `level`,
`max_hit_points`, `initiative`, `armor_class`, `damage_dice`, `damage_type`,
`attacks_per_action`, `weapon_attack_bonus`, `weapon_damage_modifier`,
`critical_hit_threshold`, `proficiency_bonus`, `spellcasting_feature`,
`spell_save_dc`, `spell_attack_bonus`, `spells`, `gambits`,
`passive_effect_payloads`, `defenses` (a `Combatant::Defenses`) and the
six `*_modifier`s. Participants compare by identity, so a party lookup no longer
compares records by id. Building one rolls any dice of a `uses_formula`, which is
why they are built in party order inside the seeded block. Same RNG draws and
golden files; casting a spell no longer looks it up by slug, one query less per
cast (the query ceiling only went down).

# Feature book

What a combatant knows how to do is read from one `Combat::FeatureBook` per
participant (`participant.feature_book`), built with it; the simulator no longer
walks unlocks or compares feature names.[^feature-book-rb] It is read-only and holds no counters:

| Query | Answers |
|---|---|
| `unlocks` | the unlocks in force (`PlayerCharacter#feature_unlocks`) |
| `action_payload(feature)` | the feature's action effect (`PlayerCharacter#action_payload`), nil when not unlocked, not an action at the level, or a maneuver the character has not learned |
| `unlock_with(kind)` | the unlock in force of the feature whose effect is `extra_action` (Action Surge) or `reroll_save` (Indomitable), or nil |
| `weapon_attacks_after(spell)` | how many bonus weapon attacks (a `grants_activity`'s `count`, one) follow this spell: `after.cast_with_action` `cantrip` (War Magic) only after a cantrip, `any_spell` (Improved War Magic) after any; nil for none |
| `rider(event:, applies:)` | the feature whose hit leaves the Eldritch Strike status (`rider`, `event: weapon_hit`, `applies: disadvantage_on_next_save`), or nil; its slug and name go in the attack's `riders` |
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
integer use count. Each participant keeps its counts left (`uses_left`). Each
class-feature action decrements the actor's remaining uses for that feature by 1,
floored at 0 (`spend_use!`); once exhausted, that action stops being offered.

# Outcome

- **`:draw`** — both parties have zero living combatants after a round
  (simultaneous elimination); `winning_party` is `nil`.
- **`:victory`** — exactly one party has a living combatant when the loop
  ends.
- **`:max_rounds_reached`** — the loop hit `max_rounds` with no winner and
  no draw.

[^combat-simulator-rb]: Source: `app/services/combat/simulator.rb`

[^gambit-policy-rb]: Source: `app/services/combat/gambit_policy.rb`

[^turn-executor-rb]: Source: `app/services/combat/turn_executor.rb`

[^combat-simulator-test]: Source: `test/services/combat/simulator_test.rb` (the turn executor's, policy's and `action_options` tests are beside it)

[^feature-book-rb]: Source: `app/services/combat/feature_book.rb`

[^participant-rb]: Source: `app/services/combat/participant.rb`

[^encounter-rb]: Source: `app/services/combat/encounter.rb`

[^status-rb]: Source: `app/services/combat/status.rb`

[^rider-rb]: Source: `app/services/combat/rider.rb`
