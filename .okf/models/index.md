# Models

* [PlayerCharacter](player-character.md) - Character record: ability scores, class, level/proficiency, HP.
* [PlayerClass](player-class.md) - D&D 5e class definition: hit die, spellcasting modifier.
* [ClassLevelProgression](class-level-progression.md) - Per-level table of proficiency bonus, ASI flag, attacks-per-action.
* [Combatant](combatant.md) - Polymorphic in-combat participant, tracking in-combat HP.
* [ClassFeature](class-feature.md) - Identity/base behavior of a class ability, separate from spells.
* [ClassFeatureUnlock](class-feature-unlock.md) - Per-level unlock/scaling row; bridge to the combat effect pipeline via effect_payload.
