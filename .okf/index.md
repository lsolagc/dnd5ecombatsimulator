---
okf_version: "0.2"
---

# D&D Combat Simulator — Knowledge Bundle

* [architecture/](architecture/) - System layering, Combat::Simulator (the official combat orchestrator), the Combat::* effect pipeline, passive effect triggers, simulation batches, gambits, and how the legacy EncounterService was retired.
* [models/](models/) - Persisted ActiveRecord models: characters, classes, progression, combatants, and class features.
* [ui/](ui/) - ERB view layer styled with Bootstrap.
* [ops/](ops/) - Local development setup and testing.
* [Ubiquitous language](ubiquitous-language.md) - The agreed vocabulary in one place (action, attack, effect; condition, status, criterion) and each term's name in code.
