---
type: Decision
title: Gambits — decisions taken autonomously while building the FFXII-style turn AI
description: Refinement questions raised per pass of the gambits work (feat/gambits), with the decision taken and why, for the user to veto at the end.
tags: [combat, decision, gambits]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-08T23:50:00Z
status: draft
---

# Context

Affects [CombatSimulatorService](/architecture/combat-simulator-service.md) turn choice and [simulation batches](/architecture/simulation-batches.md) logs.

The gambits task ran autonomously (CLAUDE_AUTONOMOUS=1). Decisions the user had
already taken are in the task text (no gambit enabled = random; gambits but none
fires = idle; presets are copies both ways; polymorphic `gambits` table; condition
enum in code). Everything below was decided by the agent and is open to veto.

# FFXII reference (research summary)

- A gambit = target+condition ("Ally: HP < 70%") + action ("Cure") + its slot
  (priority). Slots are an ordered list; each slot has an on/off toggle.
- Evaluated top to bottom whenever the character is ready to act; the first slot
  whose condition finds a valid target and whose action can be performed (MP,
  ability known) runs. A slot with no valid target or no resource is skipped.
- Targets are Self, Ally (the party, self included) or Foe.
- Nothing fires → the character stands idle. Player commands outrank gambits.
- Slots are unlocked through the License Board (up to 12) and reordered in the menu.

Simplifications here: 6 slots, no license unlocks, no player commands, one
condition per slot, conditions limited to what the simulator can observe.

# Pass 1 — model and evaluator (POC)

| Question | Decision | Why |
|---|---|---|
| Slots with gaps (FFXII allows empty slots between rules)? | Compact list: positions 1..n, n ≤ 6; the UI shows 6-n empty slots after the rules. | An empty slot is skipped anyway, so gaps carry no behavior; compact positions keep reorder a permutation. |
| Several valid targets — which one? | Candidates are walked in initiative order; the first that satisfies the condition wins (selector conditions take the min/max, ties by initiative order). | Task requires a fixed criterion, never a draw; initiative order is already seeded and deterministic. |
| Does "Aliado" include the actor? | Yes. | Same meaning as the existing payload `"ally"` target and FFXII's Ally. |
| Can any target be paired with any action? | No: validated against the action's natural target. Attack and enemy payloads → Inimigo; `self` payloads → Self (Action Surge joins in pass 2); `ally` payloads → Aliado or Self. | Avoids rules that can never fire or would heal an enemy. |
| A rule references an action the character lacks (e.g. preset from another subclass)? | Valid record; skipped at runtime as "action unavailable". | Lets presets be applied across characters, like FFXII skipping an unknown ability. |
| An action with several attacks loses its target mid-action? | The remaining attacks re-run the rule's target pick; if nothing qualifies, the first living enemy in initiative order. | 5e lets the fighter switch targets; stopping would waste attacks. |
| RNG draws for gambit-driven actors? | A gambit-driven choice consumes no `@rng` draw (no `sample`). Random-mode actors keep the exact same draw sequence. | Determinism of existing simulations and tests. |
| Gambits with all slots disabled? | Same as no gambits: random. | Task decision "sem nenhum gambit ligado". |
| Which payload decides a class feature's natural target? | The highest-level unlock that has a payload; payloads with a `trigger` (passives) or a kind other than heal/damage are rejected. | Matches what the simulator offers as an action; a passive rule could never fire. |
| Gambits snapshot for batches? | Deferred to pass 3 (log): pass 1 reads `combatant.gambits` live. | Reviewer flagged that editing gambits mid-batch breaks seed reproduction; pass 3 fixes it with a snapshot the simulator runs from. |

**Pass 1 status (2026-10-09):** code complete and suite green, but the adversarial
review still blocks after 3 iterations, on test gaps only (a pinned test for the
random path, `any` drawing no `@rng`, a spell rule matching its own FK, and a
multi-rule determinism scenario). The user allowed 3 more iterations; iteration 4 closed those, iteration 5 covered priority-by-position after out-of-order creation and single spell-slot consumption; iteration 6 pinned the random path for casters and War Magic, and the review came back non-blocking. Committed.
