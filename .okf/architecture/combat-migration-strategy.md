---
type: Decision
title: Phased migration off EncounterService onto Combat::*
description: Why the Combat::* pipeline is being introduced additively — a three-phase plan that keeps EncounterService untouched until an explicit combat-system refactor is in scope.
tags: [combat, decision, evolution]
generated:
  by: copilot-cli/claude-sonnet-5
  at: 2026-08-21T23:39:26Z
status: stable
---

# Overview

Because [encounter-service.md](/architecture/encounter-service.md) is
documented and treated as frozen until a broader combat-system refactor is
explicitly scoped, new combat capability
([combat-effect-pipeline.md](/architecture/combat-effect-pipeline.md)) is
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

**Phase 2 — standardization (not started).** Migrate the basic attack itself
onto `CombatAction`, and unify combat logging on a single `EffectResult`
shape.

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
[CombatSimulatorService](/architecture/combat-simulator-service.md) runs
attacks and class features side by side in its own turn loop, seeded for
reproducibility, without touching `EncounterService` at all. That satisfies
the same low-invasion principle from a different angle — a second
orchestrator rather than an edit to the frozen one — but it means the
codebase now has *two* combat orchestrators (`EncounterService` and
`CombatSimulatorService`) plus the effect pipeline they both partially use,
not the single eventual replacement the three-phase plan originally
implied. Anyone continuing this work should decide explicitly whether
`CombatSimulatorService` **is** intended to become the Phase 2/3 target, or
whether it is a parallel experiment — that decision has not been recorded
yet.

Anyone picking up Phase 2 or 3 should re-check this decision is still current
— it records a sequencing choice, not a guarantee that the plan hasn't moved.
