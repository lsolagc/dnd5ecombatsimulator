---
type: Report
title: Indomitable against spell saves — mechanics impact report
description: Indomitable rerolls a failed save against any effect, Fireball included, through one reroll rule (kind reroll) decided in EffectExecutor#apply_save, and a reroll with advantage or disadvantage rerolls one die only; the golden-file proof and the measured effect over 200 seeds per composition.
tags: [combat, fighter, saving-throw]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-02T00:00:00Z
sources:
  - id: executor-rb
    title: app/services/combat/effect_executor.rb
    resource: ../../app/services/combat/effect_executor.rb
  - id: saving-throw-rb
    title: app/services/combat/saving_throw.rb
    resource: ../../app/services/combat/saving_throw.rb
  - id: d20-roll-rb
    title: lib/dice/d20_roll.rb
    resource: ../../lib/dice/d20_roll.rb
  - id: executor-test
    title: test/services/combat/turn_executor_test.rb
    resource: ../../test/services/combat/turn_executor_test.rb
status: draft
---

# Context

Indomitable (Fighter 9): reroll a saving throw that failed, keeping the new result. Until 2026-11-02 the
simulator rerolled only against a class feature: `Combat::TurnExecutor#use_feature` read the target's
`reroll_save` unlock and passed `reroll_saving_throw` down the pipeline, `#cast_spell` did not, so a
Fighter never rerolled a Fireball (issue #51). And `Combat::SavingThrow` rerolled the whole roll, both
dice of a disadvantage, where the PHB (Advantage and Disadvantage) rerolls only one of them.

# Mechanical change

Decided with the user (D1, D2):

- One reroll rule for any source: the kind `reroll_save { when: failed }` became `reroll { roll:
  saving_throw, when: failed }` (`ClassFeatureUnlock::EFFECT_KINDS`, seed, fixtures, template).
- `EffectExecutor#apply_save` is the one place it is decided: the target's
  `Participant#rerolls_for(:saving_throw)` (the reroll unlocks with a use left) go to
  `SavingThrow.new(rerolls:)`, which uses each at most once while the save fails, and the target spends a
  use of each it used (`Participant#spend_rerolls!`).[^executor-rb][^saving-throw-rb] A feature, a spell or
  a maneuver with a save all go through it; `reroll_saving_throw` is gone from `TurnExecutor`,
  `ActionRunner` and `EffectExecutor`.
- `Dice::D20Roll#reroll_lower_die` rerolls the lower die and keeps the higher, then the lower of the two
  with disadvantage, the higher with advantage; one die is rolled again.[^d20-roll-rb] Under Eldritch
  Strike a reroll now draws one d20, not two.

RNG: a rerolled save draws one d20 more than before (none was rerolled against a spell before), so a
seed with such a save replays differently from it on.

# Proof on the golden files

Golden files regenerated; `queries.yml` unchanged. 68 of 72 seeds identical to HEAD. Only Fireball
calls for a save in the seed content, and only the Campeão (9) and the Mestre de Batalha (15) have
Indomitable, so only `cavaleiro-vs-campeao` and `campeao-cavaleiro-vs-mestre` can change. Each changed
seed is identical up to its first Fireball whose save failed (full damage in the old log), and that
save is rerolled now (a spy on `SavingThrow`):

| Composition, seed | Old Fireball save (failed) | Now | First difference |
|---|---|---|---|
| cavaleiro-vs-campeao 3 | r2t1, 27 damage, under Eldritch Strike | rerolled one die with disadvantage, fails again (natural 11, DC 16) | the next entry (r2t2): the extra d20 shifts the dice |
| cavaleiro-vs-campeao 6 | r1t1, 26 damage | rerolled, passes (natural 14, total 16, DC 16): 13 damage | the Fireball itself; the fight lasts 4 rounds, not 3 |
| campeao-cavaleiro-vs-mestre 3 | r1t3, 29 damage | rerolled, fails again | the War Magic attack after it; 2 rounds, not 3 |
| campeao-cavaleiro-vs-mestre 10 | r1t3, 22 damage | rerolled with disadvantage, fails again | r2t1, the next d20 |

The other five seeds with a failed Fireball save also reroll now and replay unchanged: four Fireballs
were the killing blow (nothing rolls after them) and one (`cavaleiro-vs-campeao` 12) failed again and
the extra d20 happened to leave the following draws equal (Ruby's `rand(1..n)` rejects and redraws a
value over the range, and the rejected word fell where the old sequence redrew). Tests cast Fireball at
a Fighter with Indomitable (a reroll spends the use, none without it) and under Eldritch Strike (three
d20s in all: one die rerolled, the disadvantage kept).[^executor-test]

# Measured effect (200 seeds per composition, main vs this change)

| Composition | Party one wins | Rounds | Damage per round | Saves rerolled (with disadvantage, then passed) |
|---|---|---|---|---|
| cavaleiro-vs-campeao | 23.5% → 20.5% | 4.105 → 4.150 | 20.11 → 19.69 | 0 → 67 (30, 17 passed) |
| campeao-cavaleiro-vs-mestre | 97.5% → 97.5% | 2.305 → 2.310 | 30.66 → 30.57 | 0 → 92 (42, 9 passed) |
| the other four | unchanged | unchanged | unchanged | 0 → 0 |

Damage per round is the HP lost to attacks and damage effects over all rounds. The knight loses 3 points
of win rate against the Campeão, whose Indomitable turns about a quarter of its rerolled Fireball saves
into half damage; against the Mestre de Batalha the pair wins anyway. Benchmark (`RAILS_ENV=test`,
Docker): every composition within −5.2% to +3.1% of the relative baseline.

Risks: the reroll is always spent on the first failed save (issue #53 is when to keep it); the round_log
still does not record saves, so a reroll is visible only through its effect on the amount.

[^executor-rb]: Source: app/services/combat/effect_executor.rb
[^saving-throw-rb]: Source: app/services/combat/saving_throw.rb
[^d20-roll-rb]: Source: lib/dice/d20_roll.rb
[^executor-test]: Source: test/services/combat/turn_executor_test.rb
