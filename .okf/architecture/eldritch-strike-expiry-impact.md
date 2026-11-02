---
type: Report
title: Eldritch Strike expires — mechanics impact report
description: Eldritch Strike's disadvantage expires at the end of the knight's next turn (dead or alive) instead of lasting until used up; the golden-file proof and the measured effect over 200 seeds per composition.
tags: [combat, eldritch-knight]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-02T00:00:00Z
sources:
  - id: encounter-rb
    title: app/services/combat/encounter.rb
    resource: ../../app/services/combat/encounter.rb
  - id: simulator-rb
    title: app/services/combat/simulator.rb
    resource: ../../app/services/combat/simulator.rb
  - id: encounter-test
    title: test/services/combat/encounter_test.rb
    resource: ../../test/services/combat/encounter_test.rb
  - id: turn-executor-test
    title: test/services/combat/turn_executor_test.rb
    resource: ../../test/services/combat/turn_executor_test.rb
status: draft
---

# Context

Eldritch Strike (Eldritch Knight 10, PHB): a creature hit by the knight's weapon has disadvantage on the
next saving throw it makes against a spell the knight casts **before the end of the knight's next turn**.
Until 2026-11-02 the simulator kept that `disadvantage_on_next_save` status with `ends: nil`: only a save
spell from the knight used it up, so it could last the whole fight (issue #50; see
[eldritch-strike-save-impact.md](/architecture/eldritch-strike-save-impact.md) for the previous change).

# Mechanical change

- Two new `Combat::Status::ENDS`: `source_next_turn_end` and `source_turn_end`. `Encounter#start_turn(actor)`
  turns the actor's `source_next_turn_end` statuses into `source_turn_end` (besides expiring
  `source_turn_start` as before); the new `Encounter#end_turn(actor)` expires its `source_turn_end`
  ones.[^encounter-rb] A status applied in the knight's turn N lasts through turn N + 1; a new hit renews it
  and the count starts over.
- `Combat::Simulator#play_round` calls `end_turn` for every actor whose turn started, dead or alive, after a
  living actor's `turn_end` passives; when the round stops because the fight is over it is not called
  (nothing left to expire for).[^simulator-rb] It draws nothing from the RNG, so nothing changes for a fight
  without these statuses.
- The `rider` effect kind declares `ends` (required, from `Combat::Status::ENDS`); Eldritch Strike's seed
  and fixture declare `ends: source_next_turn_end`, and `Combat::TurnExecutor` applies the status with it.

# Proof on the golden files

A control version, identical except that `end_turn` expires nothing, regenerates all six golden files and
`queries.yml` byte for byte as at commit 897af32: the new phases change nothing else. With the expiry, 71
of 72 seeds are identical; `queries.yml` unchanged. The one that changed, `cavaleiro-vs-campeao` seed 5:
the knight hits the Campeão three times in round 1 (turn N, Eldritch Strike on each), casts Scorching Ray
in round 2 (turn N + 1, no save: the mark stays and expires at the end of that turn) and Fireball in round
3. Before, that Fireball's save rolled with disadvantage from the stale mark and failed (22 damage); now
it rolls one die, succeeds and takes half (11). The Fireball kills either way and is the seed's last draw,
so only that `amount` changed. A spy on `Participant#take_statuses` in the control version finds exactly
one save with disadvantage from an expired mark across the 72 seeds: this one.

Tests: the two phases on `Encounter` (lasts through N + 1, gone at its end, renewal starts over,
`source_turn_start` as before, another source's untouched);[^encounter-test] a Fireball on the knight's
next turn rolls with disadvantage, one two turns later does not;[^turn-executor-test] a fallen knight's
status still expires at the end of its next turn; the rider without `ends` or with an unknown one is
invalid.

# Measured effect (200 seeds per composition, 897af32 vs now)

Before is the control version above (it reproduces 897af32). Saves with disadvantage: saves that used
an Eldritch Strike mark; stale: of those, the ones whose mark had already expired under the 5e rule;
expired unused: marks removed by `end_turn` before any save used them.

| Composition | Party one wins | Rounds | Damage per round | Saves with disadvantage (stale) | Expired unused |
|---|---|---|---|---|---|
| cavaleiro-vs-campeao | 20.5% → 21.0% | 4.150 → 4.150 | 19.69 → 19.72 | 36 (13) → 23 (0) | 0 → 151 |
| campeao-cavaleiro-vs-mestre | 97.5% → 97.5% | 2.310 → 2.315 | 30.57 → 30.54 | 45 (2) → 43 (0) | 0 → 28 |
| the other four | unchanged | unchanged | unchanged | 0 → 0 | 0 → 0 |

The other four have no Eldritch Strike (knight below level 10, or none). A third of the 1v1 knight's
disadvantaged saves came from a stale mark; they are gone, yet win rate and damage stay within the noise
of 200 runs (the extra die shifts the RNG, so seeds diverge after the first difference). Most marks now
expire unused: the 1v1 knight hits several times per turn but casts Fireball rarely, on its random path.

Benchmark (`combat_regression:benchmark`, Docker + YJIT, 40 rounds): every composition within −5.0% to
+2.7% relative of the baseline.

# Residual risks

- `end_turn` does not run when the round stops because the fight is over: harmless today (nothing reads
  statuses after the fight), but a future end-of-fight report on statuses would see them.
- A status applied outside the source's own turn (a reaction, none today) would last until the end of the
  source's next turn, which is what 5e says for Eldritch Strike but may not fit another feature.
- `source_turn_end` is reachable only from `source_next_turn_end`; nothing declares it directly yet.

[^encounter-rb]: Source: app/services/combat/encounter.rb
[^simulator-rb]: Source: app/services/combat/simulator.rb
[^encounter-test]: Source: test/services/combat/encounter_test.rb
[^turn-executor-test]: Source: test/services/combat/turn_executor_test.rb
