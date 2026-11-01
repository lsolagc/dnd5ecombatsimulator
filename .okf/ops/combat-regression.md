---
type: Runbook
title: Combat regression safety net
description: Golden files, query ceiling and time benchmark that prove a Combat::Simulator refactor changes neither behavior nor performance; how to run, regenerate and read the baseline.
tags: [testing, performance, combat]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T00:00:00Z
sources:
  - id: compositions
    title: lib/combat_regression.rb
    resource: ../../lib/combat_regression.rb
  - id: test
    title: test/services/combat_regression_test.rb
    resource: ../../test/services/combat_regression_test.rb
  - id: tasks
    title: lib/tasks/combat_regression.rake
    resource: ../../lib/tasks/combat_regression.rake
status: draft
---

# Overview

Phase 0 of the DDD refactor of the combat simulator (then `CombatSimulatorService`, since phase 3.5
[Combat::Simulator](/architecture/combat-simulator.md), `Combat::GambitPolicy` and `Combat::TurnExecutor`):
three checks over the same compositions, defined once in `CombatRegression::COMPOSITIONS`, on the
content of `db/seeds` (Campeão, Cavaleiro Arcano, Mestre de Batalha, levels and choices adjusted per
composition, every change rolled back). Six compositions × seeds 1–12 = 72 simulations: 1v1 and 2v1,
random and gambit-driven, one cut at `max_rounds: 2`, and one (`defesas`) that gives the characters
resistances, an immunity and a vulnerability, which no seed character has.[^compositions] Each
character entry names a seed character (distinct within its composition) and may change only its
`level`, add `spells` to the seed's, replace its known `maneuvers`, give it `gambits` (in `add_rule!`'s
shorthand: target enemy, condition any and Ataque unless given) and set its `defenses`
(`CombatRegression.prepare!`).

- **Golden files** (`test/fixtures/files/combat_regression/<composition>.yml`): the whole result of
  every seed, compared byte for byte. YAML keeps symbols apart from strings; record ids (which change
  between runs) become the character's name or the feature's or spell's slug. The test also fails if
  the set stops covering a critical hit, a maneuver rider (also on a crit), Distracting Strike's
  advantage, a spell turn, War Magic's bonus attack, Action Surge at random and by gambit, a Second
  Wind heal, a gambit entry, an idle entry, both outcomes, Eldritch Strike's disadvantage on a save
  (counted by a spy on `Combat::ActionRunner.call`), and damage halved by a resistance, blocked by an
  immunity and doubled by a vulnerability (read off the log: damage rolled against HP lost).[^test]
- **Query ceiling** (`queries.yml`): per composition, the most queries any seed runs (schema lookups
  aside) must stay within the baseline + 10%. In the suite: query counts are deterministic.[^test]
- **Time benchmark** (`benchmark.yml`, outside the suite): median ms per simulation over 40 rounds
  that take turns over the compositions, in one process, test environment, seeds loaded in a
  transaction that rolls back. Each round also times a yardstick (30 `SELECT 1` and a fixed Marshal
  round trip); the check compares the **relative** time (ms ÷ yardstick), which cancels the machine's
  own drift: absolute ms moved ±25% between runs of unchanged code on WSL, the relative time ±6%.
  Unchanged code still moves up to ~7.5% between runs in Docker, so one run over the baseline + 10%
  triggers a second, fresh measurement, and the task exits 1 only when that one is over too; a
  slowdown of ~12% was caught. The hard performance gate is the query ceiling above; the time
  benchmark is the alarm for slowdowns that add no queries. The
  yardstick does **not** cancel a change of environment or entry point: unchanged code measured +40%
  on the host (no YJIT) against the Docker + YJIT baseline, and +18% under `bin/rails runner` against
  the rake task. So the task aborts when the docker flag, Ruby build or CPU differ from the
  baseline's, and comparisons go only through `combat_regression:benchmark`.[^tasks]

# Steps

```bash
docker compose exec app bin/rails test test/services/combat_regression_test.rb   # golden + queries (also part of bin/rails test)
docker compose exec app bin/rails combat_regression:regenerate                   # rewrite goldens and queries.yml from the current code
docker compose exec -e RAILS_ENV=test app bin/rails combat_regression:benchmark  # compare with benchmark.yml (RUNS=n to change the 40 rounds)
docker compose exec -e RAILS_ENV=test -e RECORD=1 app bin/rails combat_regression:benchmark  # record a new baseline
```

On the host, wrap them in `bash -ic '…'` (test DB credentials). Regenerate only on purpose (a change
that is meant to alter combat) and review the diff; on unchanged code it is a no-op. Record the
benchmark baseline on the machine that compares, right before the refactor; `benchmark.yml` keeps
the machine and versions it was recorded on.

A change meant to touch only the result's shape, not the combat, regenerates the goldens and proves
it: load the old ones from git (`git show HEAD:<path>`, `YAML.unsafe_load`), drop the removed keys,
drop the added ones from the new, and compare every seed. Phase 2.1 (2026-10-17) did so: without
`message` (recursively) and the top-level `gambits` on the old side and `initiative` on the new, all
six compositions were identical, which also shows recording the initiative rolls drew nothing extra.

# Determinism

The order of two lists decides what a seed picks: the character's spells and the class feature
unlocks. Both load in a fixed order since phase 1.2 (`PlayerCharacter#spells` in the order learned,
`#feature_unlocks` by unlock id), so a seed replays the same whatever the tables' physical order; a
test reorders the rows and checks it. Before that they loaded with no `ORDER BY` (the spells through a
hash join on a table `SeedData` updates in place), and the harness had to pin the order itself.

# Baseline (2026-10-13)

Docker Desktop on WSL2 (Linux 6.18.54), AMD Ryzen 7 2700 (16 threads), Ruby 3.4.2 + YJIT, Rails 8.0.2,
Postgres 16.15, 40 rounds. Re-record it (`RECORD=1`) whenever a composition is added, or the kernel
or Docker changes: a WSL kernel update alone moved absolute times by ~18%.

| Composition | ms/sim | relative | queries/sim (max) |
|---|---|---|---|
| campeao-vs-mestre | 35.75 | 1.022 | 29 |
| mestre-cavaleiro-vs-campeao-gambits | 57.84 | 1.650 | 47 |
| cavaleiro-vs-campeao | 38.20 | 1.087 | 29 |
| campeao-cavaleiro-vs-mestre | 54.24 | 1.538 | 47 |
| defesas | 67.36 | 1.904 | 51 |
| mestre-vs-cavaleiro-curto | 29.57 | 0.842 | 30 |

Not covered: Indomitable (no seed feature forces a save, so its reroll never runs on real content).

[^compositions]: Source: `lib/combat_regression.rb`
[^test]: Source: `test/services/combat_regression_test.rb`
[^tasks]: Source: `lib/tasks/combat_regression.rake`
