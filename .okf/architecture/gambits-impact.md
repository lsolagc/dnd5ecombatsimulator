---
type: Report
title: Gambits — mechanics impact report
description: What the FFXII-style gambits changed in CombatSimulatorService's combat behavior, how it was validated, the measured effect on a real Brenna x Corwin matchup, and the residual risks.
tags: [combat, gambits]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-09T22:20:00Z
verified: { by: human:lsolagc, at: 2026-10-11T20:24:03Z }
status: stable
---

# Context

Before this work, [CombatSimulatorService](/architecture/combat-simulator.md)
picked every action and target with `sample(random: @rng)`. Characters can now carry
up to 6 [gambits](/models/gambit.md) that choose for them; decisions are in
[gambits-decisions.md](/architecture/gambits-decisions.md).

# Mechanical change

- **No enabled gambit → unchanged.** The random path is byte-for-byte the old one,
  pinned by two goldens recorded from the pre-gambits code (fighters; Eldritch Knight
  with War Magic) and an equivalence probe over 45 seed/composition pairs.
- **With gambits:** rules top to bottom; the first enabled rule whose action is
  available and whose condition finds a target decides; none → the actor stands idle.
  Targets are walked in initiative order (ties too); no `@rng` draw.
- **Action Surge** becomes a rule (Self): when it wins, the list runs twice more; a
  gambit-driven actor no longer surges automatically.
- **War Magic** stays automatic; for a gambit-driven actor its bonus attack aims at the
  spell's target (or the first living enemy by initiative), deterministically.
- **Reactions and passives** (Indomitable, Eldritch Strike, Survivor, fighting styles,
  criticals) are unchanged.
- **Batches** run from a copy of the rules taken at creation; logs show each
  combatant's rules and the rule that fired every turn.

# Evidence

- Tests: 363 unit/integration + 30 system tests green; every pass reviewed
  adversarially, each invariant proven by sabotage (a test goes red, code restored).
- Inventory: each of the 13 turn actions (Ataque, Second Wind, Action Surge, 5
  maneuvers, 5 spells) has a test where a single gambit fires it, on the real seeds.
- Real batch on dev: batch #9, Brenna Ironhide x Corwin Vale, 50 combats; the zip
  shows both rule sets and the rule per turn. Every enabled rule fired (Brenna 1/2/3:
  40/28/258; Corwin 1/2/3/4/6: 50/293/7/29/2).

# Observed impact (Brenna x Corwin, seeds 1–200, same characters)

| Mode | Brenna wins | Corwin wins | Avg rounds | Idle turns |
|---|---|---|---|---|
| Random (no gambits) | 87 (43.5%) | 113 (56.5%) | 5.64 | 0 |
| Gambits (Brenna and Corwin setup) | 81 (40.5%) | 119 (59.5%) | 5.36 | 0 |

A 3-point shift toward Corwin and 0.28 fewer rounds — within the noise of 200 runs
(±3.5 points standard error on the win rate), so the setups do not distort this
matchup. The larger effect is qualitative: Corwin surges on turn 1 in every fight and
spends his dice on Precision Attack instead of at random.

# Residual risks

- **"Status" is only the Distracting Strike mark**, relative to the actor
  (`marked_for?` ignores the actor's own mark). In a 1x1, `não marcado` is always true,
  which is why Corwin's Distracting Strike rule ships disabled.
- **Corwin's rule 6 (Ataque) is nearly unreachable in a 1x1** while a die is left
  (Disarming with "menor HP" takes the turn); 2 of ~430 decisions in batch #9.
- **A rule can waste a resource**: a surge whose two evaluations both stand idle spends
  its use for nothing (FFXII-faithful, accepted).
- **Fixed seeds in tests** (goldens, firing seeds) must be re-recorded against the
  pre-gambits code if the RNG sequence ever changes legitimately.
- **Log cosmetics**: inside `round_log`, each turn's `gambit` hash comes back from jsonb
  as `rule, position`; the section at the top of each file is reordered for reading.
