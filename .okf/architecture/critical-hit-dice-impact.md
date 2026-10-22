---
type: Report
title: Critical hits roll twice the dice — mechanics impact report
description: A critical hit now rolls twice the dice (5e) instead of doubling one roll, every roll_outcome lists each die, weapon and spell attacks log one attack_roll shape, and the download rebuilds every turn's key order; the golden-file proof, the measured effect over 200 seeds per composition, queries, time and residual risks.
tags: [combat, critical-hit, dice, combat-log]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-18T00:00:00Z
sources:
  - id: dice-rb
    title: lib/dice.rb
    resource: ../../lib/dice.rb
  - id: roll-expression-rb
    title: app/services/combat/roll_expression.rb
    resource: ../../app/services/combat/roll_expression.rb
  - id: simulator-rb
    title: app/services/combat/turn_executor.rb (then app/services/combat_simulator_service.rb)
    resource: ../../app/services/combat/turn_executor.rb
  - id: simulation-batch-rb
    title: app/models/simulation_batch.rb
    resource: ../../app/models/simulation_batch.rb
status: draft
---

# Context

Three findings from reading a batch's downloaded log, approved by the user:

1. `Dice.roll(crit: true)` rolled the term's dice once and doubled the sum, and
   `Combat::RollExpression` logged one sum per term in `rolls` and the written term in
   `dice` ("1d10" on a critical hit too). In 5e a critical hit rolls twice the dice.
2. A weapon attack's `attack_roll` was built by hand in
   [CombatSimulatorService](/architecture/combat-simulator.md) as `{ natural,
   total, crit, damage }`, with `success`/`damage` beside it, while a spell attack logs
   `Combat::EffectExecutor::AttackRoll#to_h` (`{ natural, total, armor_class, hit, crit }`).
3. `simulation_runs.result` is jsonb, which reorders keys; `SimulationBatch#logs_json`
   only rebuilt the order of a simulation's top-level keys.

# Mechanical change

- **Critical hit (changes results):** `Dice.roll` rolls `2n` dice for an `nd` term on a
  critical hit and keeps each die in `Dice::RollResult#rolls`;[^dice-rb] the flat
  modifiers are still added once. `RollExpression` logs the dice as rolled (`"2d10"`) and
  one value per die in `rolls`, with or without a crit (`"2d6"` → `[3, 4]`).[^roll-expression-rb]
  This covers every crit path: the weapon's damage, a spell attack's damage and a
  maneuver's die riding on a critical hit. The mean is the same; the variance of the
  critical damage dice halves (2·Var(die) instead of 4·Var(die)).
- **RNG:** a critical roll draws one die more per die of the term, so a seed plays
  differently from its first critical attack roll on (hit or miss: the damage is rolled
  before the miss is applied). Without a critical roll a seed replays exactly.
- **Log format (no mechanical change):** a weapon attack logs the effect's keys, like a
  spell's damage: `{ kind: :attack, target_id, target_name, advantage, riders, amount,
  hp_before, hp_after, roll_outcome, attack_roll }`, its `attack_roll` the same
  `{ natural, total, armor_class, hit, crit }` (the target's effective AC).[^simulator-rb]
  Gone: `success` (= `attack_roll.hit`), `damage` (= `amount`) and `attack_roll.damage`
  (= `roll_outcome.total`); new: `roll_outcome`.
- **Export (no mechanical change):** `logs_json` rebuilds every hash below a simulation in
  the order the simulator builds it (`SimulationBatch::SIMULATION_LOG_ORDER`), unknown keys
  last; the column stays jsonb.[^simulation-batch-rb]

# Evidence

- Tests: a critical `1d10 + 2` rolls two dice (seeded, compared with the two `rand`
  draws): `dice: ["2d10"]`, both values in `rolls`, total their sum + 2; `"2d6 + 1d4"`
  without a crit lists three values. A weapon attack and a Fire Bolt spell attack against
  a Fighting Style: Defense target log `attack_roll` with the same keys in the same order
  and `armor_class` = base + 1 (since 2026-10-18 the +1 is a passive the test declares). Every golden-file result saved as a `SimulationRun`
  (jsonb, checked to have reordered the keys) comes back from `logs_json` in the
  simulator's order, an unknown key last. `SimulationRunTest` (metrics) unchanged and green.
- Sabotage, each red then restored by copy: doubling the sum again (two variants: one sum
  doubled, one die repeated) fails the crit test; a hand-built weapon `attack_roll`
  without `armor_class`/`hit` fails the attack-roll test; `logs_json` without the
  reorder, and with only the top level reordered, fail the export test; dropping `:attack`
  from `SimulationRun.damage_dealt` fails the metrics test.
- Golden files regenerated. Proof script: each new result converted back to HEAD's shape
  (attack entry rebuilt, `rolls` summed per term) against HEAD's golden files, 72 seeds:
  - **28 seeds without a critical roll: identical to HEAD.**
  - 44 with one: all equal to HEAD up to the turn of the first critical roll; 40 differ
    from that turn, 1 from the turn after (its two dice summed to HEAD's doubled roll),
    3 never differ (the crit was the killing blow and both dice equalled HEAD's die).

# Observed impact (seeds 1–200 per composition, HEAD → now)

Damage is HP removed per round of combat (attacks, riders, spells, after defenses).

| Composition | Party one wins | Party two wins | Avg rounds | Dmg/round party one | Dmg/round party two | Crits/sim |
|---|---|---|---|---|---|---|
| campeao-vs-mestre | 95.5% → 94.0% | 4.5% → 6.0% | 5.78 → 5.63 | 6.72 → 6.88 | 4.76 → 4.72 | 1.32 → 1.27 |
| mestre-cavaleiro-vs-campeao-gambits | 100.0% → 100.0% | 0.0% → 0.0% | 6.40 → 6.43 | 11.75 → 11.69 | 0.00 → 0.00 | 1.02 → 0.99 |
| cavaleiro-vs-campeao | 25.5% → 23.0% | 74.5% → 77.0% | 4.14 → 4.11 | 10.62 → 10.77 | 9.23 → 9.31 | 1.02 → 1.01 |
| campeao-cavaleiro-vs-mestre | 97.5% → 97.5% | 2.5% → 2.5% | 2.31 → 2.30 | 17.84 → 17.96 | 12.85 → 12.79 | 0.88 → 0.87 |
| defesas | 89.0% → 89.0% | 11.0% → 11.0% | 6.87 → 6.63 | 6.05 → 6.24 | 8.67 → 8.77 | 2.27 → 2.25 |
| mestre-vs-cavaleiro-curto | 2.5% → 0.0% | 2.0% → 1.0% | 1.98 → 1.99 | 6.82 → 6.76 | 3.72 → 3.70 | 0.23 → 0.22 |

Verdict: **approved, no balance shift**. Win rates move 0–2.5 points, within the noise of
200 runs (1.5–3.1 points standard error); rounds −3.5% to +0.5%; damage per round −0.9% to
+3.1%. That matches the hypothesis: same mean damage on a crit, only its spread and the
draws after it change. (The gambits composition's Champion deals no damage, as at HEAD:
its attack rule needs a hurt enemy and it never gets there.)

# Queries and time

- Query ceiling: `queries.yml` re-recorded. `mestre-cavaleiro-vs-campeao-gambits` 42→43
  and `defesas` 50→46 worst-seed queries, the others unchanged. No query is new: after the
  first crit the fight takes another path, with more or fewer feature uses, and so more or
  fewer of the per-use `class_features`/`class_feature_unlocks` lookups HEAD already ran.
  The gambits worst seed (7) went from 40 to 43 queries (7 to 10 rounds); in `defesas`,
  seed 11 went from 50 to 45 (10 to 8 rounds) and seed 12 from 47 to 43 at the same 12
  rounds. Every seed without a crit has the same query count as HEAD.
- Time (host, 3 interleaved runs each against a HEAD worktree, 10 rounds of 12 seeds per
  run, median ms per simulation): −15.7% (`defesas`, shorter fights) to +0.7%
  (`campeao-vs-mestre`); relative to the yardstick −17.9% to −3.5%. No composition slower
  than HEAD by more than noise.

# Residual risks

- **Seeds replay differently** from their first critical roll on: old batch logs and
  recorded seeds with a crit are not reproducible against this code.
- **Older runs keep the old shape** in the download: `success`, `damage`,
  `attack_roll.damage`, per-term `rolls` and `"1d10"` on a crit, their unknown keys after
  the known ones. Not migrated.
- **The key order lives in `SimulationBatch::SIMULATION_LOG_ORDER`**, apart from the code
  that builds the entries; the export test replays every golden file, so a new key goes
  red there unless it is already last in its hash.
- **A weapon attack's `riders` still come before its own damage** in the entry, where they
  were at HEAD.

[^dice-rb]: Source: `lib/dice.rb`

[^roll-expression-rb]: Source: `app/services/combat/roll_expression.rb`

[^simulator-rb]: Source: `app/services/combat/turn_executor.rb` (then `app/services/combat_simulator_service.rb`)

[^simulation-batch-rb]: Source: `app/models/simulation_batch.rb`
