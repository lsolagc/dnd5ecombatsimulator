---
type: Runbook
title: Gambits work — handoff to resume the autonomous task
description: State of the 7-pass FFXII gambits task on branch feat/gambits when the session stopped, what was in progress, and the exact steps left to finish it.
tags: [gambits, ops]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-09T02:50:00Z
status: draft
---

# Where things stand (2026-10-09 ~02:50 UTC)

Branch `feat/gambits` (local only, never pushed). The original task text is the
user's prompt "Tarefa autônoma de ponta a ponta: implementar um sistema de Gambits";
every decision taken alone is in [gambits-decisions.md](/architecture/gambits-decisions.md).

| Pass | State | Commit |
|---|---|---|
| 1. POC (model + evaluator) | done, review non-blocking | `8ed5df9` |
| 2. Coverage (13 inventory actions, 5 new conditions, Action Surge via gambit) | done, last gap closed by the orchestrator (see decisions doc) | `1d18092` |
| 3. Log (snapshot + gambits section + per-turn gambit) | done, review gap closed by the orchestrator | see `git log` |
| 4. UI (6 slots, drag, toggle, edit) | done | see `git log` |
| 5. Presets | done | see `git log` |
| 6. Brenna (17) / Corwin (18) rake task | not started | — |
| 7. Refinement + real batch + final reports | not started | — |

## Pass 3 — what is on disk (uncommitted)

The builder was stopped right after reporting "all green"; nothing was sabotaged at
that moment. Verified after stopping: `bundle exec rubocop` 129 files, 0 offenses;
`bash -ic 'bin/rails test'` **324 runs, 1030 assertions, 0 failures**; the column
`simulation_batches.gambit_settings` exists in the dev DB (migration
`20261009023307_add_gambit_settings_to_simulation_batches.rb`, generated and applied).

Changed: `app/jobs/simulation_run_job.rb`, `app/models/gambit.rb`,
`app/models/simulation_batch.rb`, `app/services/combat_simulator_service.rb`,
`db/schema.rb`, tests in `test/jobs/`, `test/models/simulation_batch_test.rb`,
`test/services/combat_simulator_*_test.rb`. The spec it implements is the "Pass 3"
table of the decisions doc: copy taken at batch creation in `gambit_settings`
(missing keys only, never rewritten), runs simulated **from the copy**, `rerun` takes
current rules, `result[:gambits]` first key (per side: id, name, mode
"gambits"/"aleatório", every rule with position/enabled/target/condition/action/rule),
per decision turn `gambit: {position, rule}` | `"nenhum aplicável: parado"` |
`"aleatório"`, War Magic bonus inherits, passives carry none; zip puts `gambits`
after simulation/seed/elapsed_ms and batch.json gets `gambits` per side.

**Next step to resume:** read the pass-3 diff (`git diff`), then run the review
(`task-review` agent) with these invariants, each to be sabotaged in `app/` and shown red:
1. the run is simulated from the copy (job stops passing `gambits:` / service ignores it);
2. old log immutable (zip built from the DB instead of the copy);
3. copy never rewritten (before_validation overwrites existing keys);
4. random path identical (goldens "without gambits, …" — tuple values must not change);
5. every decision entry carries `gambit` (idle, surge marker, extra, random).
Iterate with `task-build` (max 3), then rubocop + full suite, commit with the
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` trailer, `/okf maintain`
(document `gambit_settings` and the log shape in
[simulation-batches.md](/architecture/simulation-batches.md) and
[combat-simulator-service.md](/architecture/combat-simulator-service.md)).

# Remaining passes (scope from the task text)

- **4. UI**: character gambits screen with 6 slots (compact list + empty slots), drag to
  reorder (native HTML5 DnD in a Stimulus controller first; SortableJS via importmap
  only if native is poor), up/down buttons as keyboard alternative, on/off, edit of
  target/condition/action (actions offered = the character's inventory: Ataque,
  unlocked active features incl. Action Surge, known maneuvers, known spells).
  Reorder updates every position in one transaction (unique constraint is
  deferrable). System test: dragging persists and changes simulator behavior;
  screenshot via the `ui-system-test` skill.
- **5. Presets**: `gambit_presets` (unique name) as a second polymorphic owner of
  `gambits`. From a character: "salvar como preset" (new unique name, or overwrite
  a chosen one); from another character: apply a preset (replaces its slots with a
  copy). Copies both ways, no live link. System test: save, apply, tweak the second
  character → preset unchanged; overwrite preset → second character unchanged.
  No presets in seeds.
- **6. Brenna Ironhide (17, Champion, GWF) / Corwin Vale (18, Battle Master,
  Dueling, knows Disarming, Distracting, Precision)**: idempotent rake task that
  finds them **by name**, replaces only their gambits, touches nothing else; run it
  on dev (never reset/seed the dev DB). Brenna defensive (e.g. Self HP<50% → Second
  Wind; Self HP<50% → Action Surge; Inimigo menor HP → Ataque; a disabled rule to
  show the toggle), Corwin aggressive (e.g. Self qualquer → Action Surge; Inimigo
  não marcado → Distracting Strike; Inimigo recurso ≥ 2 → Precision Attack;
  Self HP<25% → Second Wind; Inimigo menor HP → Ataque). Test: running twice
  duplicates nothing. Screenshot of each screen.
- **7. Refinement**: edge cases, a real batch Brenna x Corwin on dev whose zip shows
  both rule sets, `.okf` synced. Final deliverables: `mechanics-impact-report`,
  `ui-test-report` (Brenna/Corwin screens + presets flow), list of autonomous
  decisions (the decisions doc), inventory (Pass 2 section of the decisions doc).

# Operating notes learned this session

- Tests and rails commands need `bash -ic '...'` (DB credentials live in `~/.bashrc`).
- `~/.claude/usage.json` stopped updating at 2026-10-09T00:28 (8%); treat as stale.
- The adversarial reviewer keeps finding new test gaps each round; scoping its
  severity rule to "plausible sabotage of a listed invariant or a real bug" keeps
  rounds finite. Reviewers and builders must use their own scratchpad subfolder
  for sabotage scripts (a shared `sab.py` collided once).
- The Stop hook asks for `/okf maintain` whenever app code is uncommitted; a
  verify-gate red can come from a builder's in-flight sabotage — check before acting.
- Open items for the user's veto are flagged in the decisions doc (pass 2 closed by
  the orchestrator after 3 blocked iterations; pass 1 needed 6 iterations, user-approved).
