---
type: Report
title: War Magic — mechanics impact report
description: War Magic and Improved War Magic now grant one weapon attack instead of a whole Attack action (Extra Attack); the golden-file proof, the measured effect on the Eldritch Knight over 200 seeds per composition, and the residual risks.
tags: [combat, war-magic, eldritch-knight]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-18T00:00:00Z
sources:
  - id: simulator-rb
    title: app/services/combat_simulator_service.rb
    resource: ../../app/services/combat_simulator_service.rb
  - id: action-runner-rb
    title: app/services/combat/action_runner.rb
    resource: ../../app/services/combat/action_runner.rb
  - id: coverage-test
    title: test/services/combat_simulator_gambit_coverage_test.rb
    resource: ../../test/services/combat_simulator_gambit_coverage_test.rb
status: draft
---

# Context

War Magic (Eldritch Knight 7: after using the action to cast a cantrip, *one* weapon attack as a
bonus action) and Improved War Magic (18: the same after any spell) were run by
[CombatSimulatorService](/architecture/combat-simulator-service.md) as a whole Attack action, so a
knight with Extra Attack made `attacks_per_action` attacks: in the golden files, 71 of the 94 bonus
entries had 2 attacks and 19 had 3.

# Mechanical change

- `Combat::ActionRunner.attack` takes `attacks:` (default `attacks_per_action`), and so does
  `execute_attack_action`; `war_magic_turn` asks for 1.[^action-runner-rb][^simulator-rb]
- Unchanged: when War Magic fires, the bonus target (gambit: the spell's target if a living enemy,
  else the first living enemy in initiative order; random: a living enemy via `@rng`), the
  Distracting Strike advantage mark it consumes, the Eldritch Strike mark it leaves on a hit, and the
  Attack action itself (still Extra Attack).
- Still out: the action economy. The attack spends no bonus action ([issue #39](https://github.com/lsolagc/dnd5ecombatsimulator/issues/39)).
- RNG: one attack instead of two or three draws fewer dice, so a given seed plays differently from
  the first War Magic bonus on.

# Evidence

- Test: a level 10 knight (Extra Attack 2, Eldritch Strike) casts Fire Bolt by gambit at a marked
  target. The bonus has one attack, with advantage, and leaves the Eldritch Strike mark; the Attack
  action still makes 2 attacks.[^coverage-test] The War Magic target tests (spell's target, fallback in
  initiative order) now expect one attack. The test of a focus falling on the first of two attacks
  is gone, because War Magic never makes a second attack.
- Golden files regenerated. The compositions without an Eldritch Knight at level ≥7
  (`campeao-vs-mestre`, `mestre-vs-cavaleiro-curto`) are byte for byte HEAD's. Every bonus entry has
  ≤1 attack, and War Magic still fires after every eligible spell entry. The only one without a bonus
  entry after it ends the fight, as at HEAD. The number of bonus entries moved with the number of
  cantrips cast: 11→12, 10→11, 23→21, 50→41. In the gambits composition the dice shift let the
  Battle Master land Distracting Strike more often (24→31 entries), so the knight's `marcado → Ataque`
  rule won more often (17→25 Attack turns, 51→42 spell turns).
- Query ceiling: `queries.yml` re-recorded with this change, since the fights it measures changed:
  `defesas` rose from 51 to 55 queries for its worst seed and `campeao-cavaleiro-vs-mestre` fell from
  47 to 45, so the next phases are judged against the current fights. The cause is longer fights: 80→96 rounds over the 12
  seeds, with queries per round down from 7.28 to 6.25. The change itself adds no query.
- Time (`perf/time.rb`, 3 interleaved runs each against HEAD, median ms per simulation): −4.5%
  (gambits composition) to +3.4% (`defesas`, the longer fights); the other four −0.9% to −3.4%.

# Observed impact (seeds 1–200 per composition, HEAD → now)

Wins are the knight's side. Damage is the HP the knight takes off enemies per round of combat
(attacks, riders and spells, after defenses).

| Composition | Knight | Wins | Avg rounds | Knight dmg/round | of which bonus | Attacks per bonus |
|---|---|---|---|---|---|---|
| mestre-cavaleiro-vs-campeao-gambits | 7, gambits | 100.0% → 100.0% | 5.52 → 6.40 | 8.43 → 6.55 | 3.91 → 2.05 | 1.97 → 1.00 |
| cavaleiro-vs-campeao | 13, random | 26.5% → 25.0% | 4.02 → 4.14 | 11.63 → 10.61 | 1.66 → 0.59 | 2.91 → 1.00 |
| campeao-cavaleiro-vs-mestre | 18, random | 97.5% → 97.5% | 2.09 → 2.30 | 12.87 → 11.49 | 2.52 → 1.01 | 2.44 → 0.82 |
| defesas | 7, random | 91.0% → 89.0% | 6.32 → 6.87 | 3.08 → 2.61 | 0.61 → 0.27 | 1.91 → 0.96 |

The bonus deals 48–65% less, which matches one attack instead of two or three. The knight's total
damage per round drops 9–22%. The gambit knight drops most, because it casts Fire Bolt on most of
its turns. Fights run 3–16% longer. Win rates move by 0–2 points, within the noise of 200 runs
(a 1.5–3 point standard error). This verdict holds for these matchups only: the fix weakens the
Eldritch Knight without upsetting them, and a closer matchup can still swing. Below 1.00 attacks per
bonus are bonus entries with no attack, logged on the random path when nobody was left to hit
(already at HEAD).

# Residual risks

- **Seeds replay differently** for any combat with an Eldritch Knight at level ≥7 that casts:
  old batch logs and recorded seeds are not reproducible against this code.
- **Empty bonus entries on the random path:** `war_magic_turn` runs even after the spell ended the
  fight and logs a bonus with no attack. The gambit path skips it. This change does not touch it.
- **The `focus.dead?` fallback in `execute_attack_action`** is now unreachable from War Magic,
  because the focus is alive when the only attack starts. It stays as a guard for any other caller.
- **Still no action economy:** the bonus spends no bonus action, so it can stack with anything that
  would also need one, once those exist.

[^simulator-rb]: Source: `app/services/combat_simulator_service.rb`

[^action-runner-rb]: Source: `app/services/combat/action_runner.rb`

[^coverage-test]: Source: `test/services/combat_simulator_gambit_coverage_test.rb`
