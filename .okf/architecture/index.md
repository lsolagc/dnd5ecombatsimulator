# Architecture

* [System Architecture Overview](overview.md) - High-level layering of the simulator and how requests flow through it.
* [EncounterService — legacy combat orchestrator](encounter-service.md) - The frozen combat-encounter orchestrator; initiative, rounds, attacks, damage.
* [Combat effect-execution pipeline (Combat::*)](combat-effect-pipeline.md) - The evolving pipeline for class-feature/spell effects: CombatAction, EffectResolver, EffectExecutor, ActionRunner.
* [Phased migration off EncounterService onto Combat::*](combat-migration-strategy.md) - Why the pipeline is introduced additively, in three phases, without touching the frozen service.
* [CombatSimulatorService — seeded, feature-aware combat orchestrator](combat-simulator-service.md) - A newer, separate orchestrator combining basic attacks with class-feature effects, seeded for reproducibility.
* [Passive effect triggers (always / turn_start / turn_end)](passive-effect-triggers.md) - The trigger + conditions extension to effect_payload behind passives like Champion's improved critical.
