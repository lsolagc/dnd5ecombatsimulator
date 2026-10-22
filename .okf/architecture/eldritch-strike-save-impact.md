---
type: Report
title: Eldritch Strike kept for a save — mechanics impact report
description: Eldritch Strike's disadvantage is used up only by the knight's next spell that calls for a save, no longer by a spell attack such as Fire Bolt; the golden-file proof and the measured effect over 200 seeds per composition.
tags: [combat, eldritch-knight]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-19T00:00:00Z
sources:
  - id: simulator-rb
    title: app/services/combat/turn_executor.rb (then app/services/combat_simulator_service.rb)
    resource: ../../app/services/combat/turn_executor.rb
  - id: simulator-test
    title: test/services/combat/turn_executor_test.rb (then test/services/combat_simulator_service_test.rb)
    resource: ../../test/services/combat/turn_executor_test.rb
status: draft
---

# Context

Eldritch Strike (Eldritch Knight 10): a creature hit by the knight's weapon has disadvantage on the next
saving throw it makes against a spell the knight casts. The simulator keeps that as a
`disadvantage_on_next_save` status on the target (see
[combat-simulator.md](/architecture/combat-simulator.md)). Until 2026-10-19 any spell the
knight cast at the target used it up, so a Fire Bolt or Ray of Frost (spell attacks, no save) spent the
disadvantage without it doing anything. Decided with the user: only a spell whose payload calls for a
`save` uses it up (`Combat::TurnExecutor#cast_spell`, then `CombatSimulatorService#execute_cast_spell_action`).[^simulator-rb] The expiry at the
end of the knight's next turn is still missing: issue #50.

# Proof on the golden files

Golden files regenerated; `queries.yml` unchanged. 70 of 72 seeds identical to HEAD. The two that
changed (`cavaleiro-vs-campeao` seeds 3 and 5) are identical up to the knight's first Fireball after an
Eldritch Strike hit followed by a spell without a save (Ray of Frost, Scorching Ray): under the old rule
that spell had used the mark up, now the Fireball's save rolls with disadvantage. A test casts Fire Bolt
at a marked target, checks the mark stays, then a save spell that uses it up.[^simulator-test]

# Measured effect (200 seeds per composition, old rule vs new)

| Composition | Party one wins | Rounds | Damage per round |
|---|---|---|---|
| cavaleiro-vs-campeao | 23.0% → 23.5% | 4.110 → 4.105 | 20.09 → 20.11 |
| campeao-cavaleiro-vs-mestre | 97.5% → 97.5% | 2.295 → 2.305 | 30.75 → 30.66 |
| the other four | unchanged | unchanged | unchanged |

Within the noise of 200 runs: the knight only gains when it casts a spell attack and then Fireball at the
same marked target before hitting it again.

Risk: without an expiry (issue #50) the mark can now last several rounds until a save spell; before, any
cantrip used it up, which happened to cut it short much like 5e's "before the end of your next turn".

[^simulator-rb]: Source: app/services/combat/turn_executor.rb (then app/services/combat_simulator_service.rb)
[^simulator-test]: Source: test/services/combat/turn_executor_test.rb (then test/services/combat_simulator_service_test.rb)
