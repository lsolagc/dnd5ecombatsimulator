---
type: Service
title: Simulation batches — experiments running CombatSimulatorService N times in the background
description: The SimulationBatch/SimulationRun models, SimulationRunJob (one per simulation, run in parallel by Solid Queue workers) and the simulation_batches screen that configure, run, poll, cancel and summarize up to 1000 seeded CombatSimulatorService combats, with a zipped JSON log download.
resource: app/jobs/simulation_run_job.rb
tags: [combat, ui]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-06T02:15:00Z
sources:
  - id: batch-model
    title: app/models/simulation_batch.rb
    resource: ../../app/models/simulation_batch.rb
  - id: run-model
    title: app/models/simulation_run.rb
    resource: ../../app/models/simulation_run.rb
  - id: batch-job
    title: app/jobs/simulation_run_job.rb
    resource: ../../app/jobs/simulation_run_job.rb
  - id: batch-controller
    title: app/controllers/simulation_batches_controller.rb
    resource: ../../app/controllers/simulation_batches_controller.rb
  - id: batch-system-test
    title: test/system/simulation_batches_test.rb
    resource: ../../test/system/simulation_batches_test.rb
status: stable
---

# Overview

A batch runs [CombatSimulatorService](/architecture/combat-simulator-service.md)
(never [EncounterService](/architecture/encounter-service.md)) several times
between two sides of `PlayerCharacter`s and aggregates the results.[^batch-model]

- **`SimulationBatch`**: `party_one_ids` / `party_two_ids` (Postgres bigint
  arrays; "Lado A" / "Lado B" in the UI), `requested_count` (1..1000),
  optional `seed`, `status` (`pending → running → completed | cancelled |
  failed`) and `error_message`. Validation: both sides non-empty, no
  character on both sides (the simulator tells parties apart by AR equality),
  every id exists. A `seed` forces `requested_count = 1`.
- **Characters are blueprints.** `combatant_settings` (jsonb, keyed by
  character id) holds each combatant's experiment parameters: starting
  `current_hit_points` (1..the sheet's max HP; the max itself is never
  edited), `armor_class`, `attack_bonus`, `damage_dice` (`NdM`),
  `damage_type` and `defenses` (`{ damage_type => "R" | "I" | "V" }`, one
  flag per type, immunity outranking resistance as in the character
  wizard). `before_validation` snapshots missing entries from the sheet
  (`SimulationBatch.blueprint_settings`), so every batch records exactly what
  it ran with. `party_one`/`party_two` load fresh characters and apply the
  settings **in memory only** (`combatant.assign_attributes` +
  `current_hit_points`); nothing in the combat path saves, so the sheet never
  changes. AC and attack bonus are the sheet's base values: passive bonuses
  such as the Defense or Archery fighting styles still stack on top.
  `combatants=` reads the form (`{ id => { side, current_hit_points, … } }`)
  into the side arrays and settings; `rerun` copies combatants, settings,
  count and seed into a new unsaved batch ("Repetir com ajustes").
- **`SimulationRun`**: one row per finished combat — its `seed`,
  `elapsed_ms`, `winning_party`, `outcome`, the full result (`round_log`
  included) as `jsonb`, and three metrics extracted at save time by
  `SimulationRun.metrics(round_log)`.[^run-model]

# Execution

`SimulationBatchesController#create` saves the batch and enqueues
`requested_count` `SimulationRunJob`s at once (`ActiveJob.perform_all_later`).[^batch-controller]
Jobs run on **Solid Queue** in separate worker processes (`bin/jobs`, started
by `bin/dev`; in production inside Puma via `SOLID_QUEUE_IN_PUMA`).
Simulations are CPU-bound Ruby, so `config/queue.yml` runs one thread per
process and `JOB_CONCURRENCY` processes (default: half the CPU cores): one
batch's simulations run in parallel. Measured in development with 8
workers: 300 simulations in ~12 s, 1000 in ~39 s (was ~1 s per simulation,
in-process).

Each job runs one simulation:[^batch-job] it skips a finished batch, flips
`pending → running` and stamps `started_at` (conditional `update_all`),
loads **fresh** characters (the simulator mutates HP and spell slots in
memory), uses the batch seed or a `SecureRandom` seed, stores the run, and
`complete_if_done!` flips `running → completed` in one UPDATE guarded by
"runs ≥ requested_count", so of two workers finishing together exactly one
completes the batch. A raising simulation fails the batch (`fail!`) and the
remaining jobs skip.

**Cancelling** sets `status = cancelled`. Each job passes
`abort_if: -> { batch.cancelled_in_database? }` to the simulator, which checks
it before every round and raises `CombatSimulatorService::Aborted`; the job
re-checks once more after the simulator returns, so a combat cancelled during
its last round is dropped too. Never saved, finished ones stay; jobs not yet
started skip. `cancelled_in_database?` must bypass the query cache
(`SimulationBatch.uncached`): jobs run under it, and the web process's UPDATE
does not clear a worker's cache, so a cached `false` would never see the
cancel (it did, until a test reproduced it with a raw UPDATE).

**Progress push.** After each run the job calls `broadcast_progress`: a
Turbo Stream `update` of the `batch_status` frame with `method="morph"`, over
`turbo_stream_from` the batch, rendering the same `_status` partial. Morphing
keeps the progress bar element, so its width eases (CSS transition) instead
of jumping. Pushes are throttled across workers to one per 0.2 s
(`progress_broadcast_at`, claimed with a conditional UPDATE); the final
completion, a cancel and a failure always push. Action Cable runs on **Solid
Cable** (its own database) in development and production, since the async
adapter only delivers within one process. The partial is rendered outside any
request, so its "Interromper" `button_to` carries no token field and Turbo
sends the page's CSRF token as a header. A slow `poll` (10 s,
`refresh="morph"` frame) only covers a dropped connection.

# Metrics

- **Win rate**: `group(:winning_party).count` over the runs (`nil` = draw or
  max rounds).
- **Healing done**: HP actually restored (`hp_after - hp_before` of every
  `heal` result, passives included). **Wasted healing**: the rest of each
  heal's `amount`, i.e. what rolled past the target's max HP.
- **Biggest damage in a round**: per round, the sum of HP removed by weapon
  attacks (their `hp_before`/`hp_after`), maneuver riders and `damage`
  effects — after resistances, without overkill below 0 HP; the batch keeps
  the max.

# UI

`simulation_batches#new` is the experiment builder: one panel per side
(blue A, orange B, the dataviz-validated categorical pair), each with a
picker that clones a server-rendered `<template>` combatant card (one per
character; a character picked on one side is disabled in both pickers). Each
card edits the settings above; fields that differ from the sheet get an
`is-edited` marker and a per-card "N ajustes" count with "Restaurar ficha",
and defenses are R/I/V chips inside a `<details>`. A run bar (sticky on
desktop, static on phones) holds count and seed — the Stimulus
`simulation-form` controller disables the count at 1 while a seed is typed —
and a live "A contra B · N simulações" summary. Validation errors re-render
the cards with the submitted values.

`#show` lists each side's combatants with the parameters they ran with. The
status lives in a `batch_status` turbo-frame, updated by the pushes above
(finished count, progress bar, average `elapsed_ms`, pace in simulations per
second since `started_at`, time left at that pace, "Interromper"). Once finished the frame
renders a headline ("Lado B venceu 52,0% dos combates"), a 100% win-rate bar
(A / sem vencedor / B, with a legend carrying the numbers), tiles for
healing done, wasted healing (also as a share of healing rolled), biggest
round damage and average time, and "Baixar logs" (`#logs`): a zip (rubyzip)
with `batch.json` (setup, `combatant_settings`, summary) and one
`simulation-NNNN.json` per run, each carrying its `seed`.

# Verification

`test/system/simulation_batches_test.rb` drives the whole flow in a browser:
several characters per side with edited parameters (and the sheet left
unchanged), repeating an experiment and restoring the sheet values, the
one-side-only picker, the 1000 and max-HP caps (blocked by the browser), the seed
locking the count, a seeded batch summarized and its zip downloaded from the
running server, the progress frame picking up a run created after the page
loaded, and cancellation.[^batch-system-test] System tests do not run the job
while the page is open (`perform_enqueued_jobs` runs it synchronously), so
aborting the *in-flight* combat is only covered by the job and
`CombatSimulatorService` tests. Seed 42 is the deterministic screenshot
scenario: the same seed reproduces the same summary.

