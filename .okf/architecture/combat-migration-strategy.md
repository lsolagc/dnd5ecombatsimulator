---
type: Decision
title: Phased migration off EncounterService onto Combat::*
description: Why the Combat::* pipeline was introduced additively in three phases around the frozen EncounterService, and the 2026-10-11 decision making CombatSimulatorService the official orchestrator and removing EncounterService.
tags: [combat, evolution]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-14T00:00:00Z
verified: { by: human:lsolagc, at: 2026-10-11T18:34:04Z }
status: stable
---

# Overview

Because `EncounterService` (removed on 2026-10-11, see the last section) was
treated as frozen until a broader combat-system refactor was
explicitly scoped, new combat capability
([combat-effect-pipeline.md](/architecture/combat-effect-pipeline.md)) was
introduced **additively**, never by editing the frozen service in
place.

# The three phases

**Phase 1 — low invasion (shipped).** Add `Combat::ActionRunner`
(resolver + executor) as a single new call site per turn for special
actions; keep the existing basic-attack flow as the fallback:

```ruby
if combatant.has_selected_action?
  action_result = Combat::ActionRunner.call(...)
else
  # existing basic-attack flow
end
```

**Phase 2 — standardization (partly shipped 2026-10-11).** Migrate the basic
attack itself onto `CombatAction` — done, as the Attack action (see
[combat-action-language.md](/architecture/combat-action-language.md)) — and
unify combat logging on a single `EffectResult` shape (not started: the
simulator still builds its own attack log entries from the results).

**Phase 3 — expansion (not started).** Integrate damage/control spells into
the same pipeline, and bring rest-based resource/recharge spending into the
same transactional flow.

# Why this ordering

Migrating the basic attack (Phase 2) or adding spells (Phase 3) before the
pipeline itself is proven would mean building on unproven abstractions while
simultaneously touching the frozen service — exactly the risk the freeze
decision exists to avoid. Phase 1 validates the `CombatAction` /
`EffectResolver` / `EffectExecutor` contract against one real case
(`Second Wind`) with zero changes to `EncounterService`, before anything
depends on it.

# What actually shipped next

Rather than Phase 2 (migrating `EncounterService`'s own basic attack onto
`CombatAction`), the next concrete step was a **new, separate** orchestrator:
[CombatSimulatorService](/architecture/combat-simulator.md) runs
attacks and class features side by side in its own turn loop, seeded for
reproducibility, without touching `EncounterService` at all. That satisfies
the same low-invasion principle from a different angle — a second
orchestrator rather than an edit to the frozen one — but it meant the
codebase then had *two* combat orchestrators (`EncounterService` and
`CombatSimulatorService`) plus the effect pipeline they both partially used.

# Resolution (2026-10-11)

Whether `CombatSimulatorService` was the Phase 2/3 target or a parallel
experiment stayed open until the user settled it: `CombatSimulatorService`
**is** the official combat orchestrator and the target of Phases 2 and 3.
By then it had passives, spells, maneuvers, Action Surge, gambits and
simulation batches, while `EncounterService` still only rolled basic attacks
and had no caller outside its own test. `EncounterService` and its test were
deleted; nothing else depended on it (`attacks_per_action` and the
attack-roll methods it called stayed, since the simulator used them then;
those methods have since been replaced by the Attack action and removed, see
[combat-action-language.md](/architecture/combat-action-language.md)).

Phases 2 and 3 now apply to `CombatSimulatorService` (since phase 3.5 of the DDD refactor,
`Combat::Simulator`, `Combat::GambitPolicy` and `Combat::TurnExecutor`). The basic attack
moved onto `CombatAction` the same day; what is left of Phase 2 is the
unified log shape.
