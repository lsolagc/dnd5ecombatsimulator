---
type: Model
title: Spell, SpellSlotProgression, PlayerCharacterSpell
description: Minimal spellcasting subsystem — a spell catalog, a per-ClassFeature spell slot progression table, and per-character prepared spells — built to support the Fighter's Eldritch Knight archetype.
resource: app/models/spell.rb
tags: [model, spell, class, feature, combat, persistence]
generated:
  by: copilot-cli/claude-sonnet-5
  at: 2026-09-06T00:00:00Z
sources:
  - id: spell-rb
    title: app/models/spell.rb
    resource: ../../app/models/spell.rb
  - id: spell-slot-progression-rb
    title: app/models/spell_slot_progression.rb
    resource: ../../app/models/spell_slot_progression.rb
  - id: player-character-spell-rb
    title: app/models/player_character_spell.rb
    resource: ../../app/models/player_character_spell.rb
status: stable
---

# Overview

This is a deliberately minimal spellcasting subsystem, scoped to what the
Fighter's Eldritch Knight archetype needs — not a general-purpose engine for
the six other classes that carry a `spellcasting_modifier`
([PlayerClass](player-class.md)). There is no spell list per class, no
upcasting, and no "known vs. prepared" distinction for full casters.[^spell-rb]

`Spell` is a flat catalog (name, slug, level 0-9, school, description, an
optional `effect_payload`).[^spell-rb] A cantrip (`level.zero?`) has no
resource cost; a leveled spell consumes a slot when cast.

`SpellSlotProgression` is a per-level lookup table (cantrips known, spells
known, slots for spell levels 1-4) scoped to a **`ClassFeature`**, not a
`PlayerClass` — this is what lets a subclass like Eldritch Knight have its own
slot progression distinct from a full caster's, without changing
[ClassLevelProgression](class-level-progression.md), which stays
per-`PlayerClass`.[^spell-slot-progression-rb] `ClassFeature#grants_spellcasting`
(pre-existing) is how `PlayerCharacter#spellcasting_feature` finds the right
feature to read the table from.

`PlayerCharacterSpell` is a join recording which spells a character currently
has prepared — the stand-in for "encounter preparation" in an app with no
persisted encounter entity; a character's prepared list is just edited
directly.[^player-character-spell-rb]

# Casting a spell

`PlayerCharacter#cast_spell(slug:, targets:)` mirrors
`#use_class_feature`[^spell-rb] but goes through a real, enforced resource:

1. Looks up the spell in `spells` (must be prepared by this character).
2. If `spell.level.positive?`, decrements `available_spell_slots[spell.level]`
   — raising if none remain. `available_spell_slots` is a runtime-only Hash
   (not persisted), lazily built from the matching `SpellSlotProgression` row
   for the character's current level, the same "ephemeral per-combat state"
   pattern `current_hit_points` already uses.
3. Builds a `Combat::CombatAction` with `source_type: :spell` and runs it
   through `Combat::ActionRunner`, exactly like a class feature.

`Combat::EffectResolver` reads `Spell#effect_payload` directly for `:spell`
actions — no per-level unlock lookup, since a spell's effect doesn't scale
with caster level in this minimal model.

**Not covered**: `CombatSimulatorService`'s turn loop does not autonomously
choose to cast a prepared spell — it still only offers `:attack` and
`:class_feature` actions. Casting is proven end-to-end at the
`Combat::ActionRunner` / model level (see `test/services/combat/action_runner_test.rb`),
the same phase Second Wind was proven at before `CombatSimulatorService`
integration happened separately. See
[combat-effect-pipeline.md](/architecture/combat-effect-pipeline.md).

# Schema

**spells**

| Field | Type | Description |
|-------|------|--------------|
| name | string | e.g. `Fire Bolt` |
| slug | string | Globally unique |
| level | integer | 0 (cantrip) - 9 |
| school | string | Free-form (e.g. `evocation`, `abjuration`) |
| description | text | Flavor/rules text |
| notes | text | Optional; used to flag simplifications (e.g. an AoE spell modeled as single-target) |
| effect_payload | jsonb | Same shape as `class_feature_unlocks.effect_payload`; optional |

**spell_slot_progressions**

| Field | Type | Description |
|-------|------|--------------|
| class_feature_id | integer (FK) | → `class_features`, the spellcasting-granting feature |
| level | integer | 1-20, unique per `class_feature_id` |
| cantrips_known | integer | |
| spells_known | integer | |
| spell_slots_1..4 | integer | Slots available per spell level (1st-4th) |

**player_character_spells**

| Field | Type | Description |
|-------|------|--------------|
| player_character_id | integer (FK) | |
| spell_id | integer (FK) | Unique per `player_character_id` |
