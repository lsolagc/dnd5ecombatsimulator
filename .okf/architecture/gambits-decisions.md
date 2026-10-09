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

# Pass 2 — coverage

Inventory of the Fighter's existing features (the only class with features today):

- **Chosen by a gambit** (turn actions): Ataque; Second Wind; Action Surge; the 5 maneuvers
  with an effect (Precision, Disarming, Lunging, Sweeping, Distracting Strike); the 5 spells
  with an effect (Fire Bolt, Ray of Frost, Chromatic Orb, Scorching Ray, Fireball).
- **Automatic, not a turn choice** (stay as they are): Indomitable (reaction to a failed
  save), War Magic / Improved War Magic (bonus attack after a spell), Eldritch Strike (mark
  on hit), Survivor (turn-start heal), fighting styles and Improved/Superior Critical
  (always-on modifiers), Combat Superiority (the dice pool maneuvers spend).
- **Not executable in the simulator** (no effect payload), so not offered: the 13 other
  maneuvers, Great Weapon Fighting / Protection / Two-Weapon Fighting, Remarkable Athlete,
  Additional Fighting Style, Student of War, Know Your Enemy, Improved Combat Superiority,
  Relentless, Weapon Bond, Arcane Charge, Shield, Stoneskin.

| Question | Decision | Why |
|---|---|---|
| Should reactions and passives (Indomitable, War Magic, Eldritch Strike) be gambit actions? | No — they stay automatic. | FFXII gambits only pick the turn's action; reactions fire on their own. "Every feature can be fired by a gambit" is read as every *turn action*. |
| How does Action Surge fit an FFXII rule? | It is a gambit action (target Self). When its rule wins, one use is spent, a marker turn is logged, and the actor evaluates its gambits twice more (normal action, then `extra: true`); Action Surge rules are skipped inside those two. | Lets the user decide *when* to surge (e.g. "Self: HP < 50% → Action Surge"), and the two actions still follow the list. |
| Does a gambit-driven actor still get the automatic random Action Surge? | No: only through a rule. Random-mode actors keep the automatic one. | Fixes the pass-1 gap where an idle actor still acted at random; FFXII never acts outside the list. |
| War Magic bonus attack target for a gambit-driven actor? | The spell's target if it is a living enemy, else the first living enemy in initiative order; no `@rng`. | It stays automatic, but must be deterministic like every other gambit choice. |
| What is a "status" condition? | The only status the simulator tracks is the Distracting Strike advantage mark: `marked` = the target carries a mark the actor would use (from someone else), `unmarked` = it does not. | No other condition/status system exists; marks expire at their owner's next turn start, so the owner never sees its own mark. |
| "Resource available" condition? | `resource_at_least N`: the actor's remaining resource **for the rule's own action** is ≥ N (feature uses, the superiority-dice pool for maneuvers, slots of the spell's level). Rejected for Ataque and cantrips. The target is the first candidate in initiative order. | Availability (≥ 1) is already implied by the action check; the parameter lets a rule keep a reserve (e.g. "dados ≥ 2 → Precision Attack"). |
| Inventory tests on fixtures or real content? | Real content: each test loads `db/seeds` (SeedData.load_all, inside the test transaction) and fires the feature through a single gambit. | Proves reachability with the content the user actually runs, not a fixture double. |

Smaller choices taken while building pass 2:

| Question | Decision | Why |
|---|---|---|
| An evaluation inside an Action Surge finds no rule? | It logs an idle entry; the one for the extra action carries `extra: true`. | Keeps "the list ran twice" visible in the log. |
| The fight ends during a surge or before War Magic's bonus? | The remaining evaluation and the bonus attack are skipped (no entry). | Same as the random `action_surge_turn`, which returns nil once combat is over. |
| How does the simulator know an Action Surge rule? | `Gambit#action_surge?` (feature named "Action Surge", like `action_surge_unlock_for`); available while unlocked with uses > 0 and not already inside a surge. | One name check, shared with the existing automatic surge. |

**Pass 2 status:** code complete, suite green; every invariant proven by sabotage (scratchpad/build-p2).

**Pass 2 status (2026-10-09):** the review blocked three times on test gaps only (spell
slot level, War Magic fallback with several enemies, Action Surge uses under
`resource_at_least`). After iteration 3 the last gap was a single assertion the reviewer
had already validated; the orchestrator added it, proved `.first`, `.last` and
`sample(@rng)` red, and committed instead of stopping the task. Flagged for the user.
