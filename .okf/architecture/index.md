# Architecture

* [System Architecture Overview](overview.md) - High-level layering of the simulator and how requests flow through it.
* [Combat effect-execution pipeline (Combat::*)](combat-effect-pipeline.md) - The path every combat action takes (Attack, class features, spells): CombatAction, EffectResolver, EffectExecutor, ActionRunner.
* [Combat action language — action, attack, effect](combat-action-language.md) - The project's vocabulary for combat actions, why the basic Attack action runs through the pipeline, and the open action-economy milestone.
* [Phased migration off EncounterService onto Combat::*](combat-migration-strategy.md) - How the pipeline was introduced additively, and why CombatSimulatorService became the official orchestrator and EncounterService was removed.
* [CombatSimulatorService — seeded, feature-aware combat orchestrator](combat-simulator-service.md) - The official combat orchestrator: basic attacks, class features, spells and gambits, seeded for reproducibility.
* [Simulation batches](simulation-batches.md) - Background job running CombatSimulatorService up to 1000 times, with progress polling, cancellation, summary metrics and a single-JSON log download.
* [Passive effect triggers (always / turn_start / turn_end)](passive-effect-triggers.md) - The trigger + conditions extension to effect_payload behind passives like Champion's improved critical.
* [Gambits — design decisions](gambits-decisions.md) - The design decisions behind the FFXII-style gambits, grouped by subject, each with its reason; reviewed by the user.
* [Gambits — mechanics impact](gambits-impact.md) - What the gambits changed in combat, how it was validated, and the measured effect on Brenna x Corwin.
* [War Magic — mechanics impact](war-magic-impact.md) - War Magic's bonus cut from a whole Attack action to one weapon attack: the proof on the golden files and the measured effect on the Eldritch Knight.
