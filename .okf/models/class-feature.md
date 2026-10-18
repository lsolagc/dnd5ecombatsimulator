---
type: Model
title: ClassFeature
description: The identity and base behavior of a class ability (e.g. Second Wind, Rage, Ki) — action cost, resource, recharge rule — kept in a table separate from spells.
resource: app/models/class_feature.rb
tags: [class, feature, persistence]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-18T00:00:00Z
verified: { by: human:lsolagc, at: 2026-10-11T21:00:19Z }
sources:
  - id: class-feature-rb
    title: app/models/class_feature.rb
    resource: ../../app/models/class_feature.rb
status: stable
---

# Overview

`ClassFeature` models a class ability's identity and base behavior — deliberately
covering **all core D&D 5e classes** (Barbarian, Bard, Warlock, Cleric,
Druid, Sorcerer, Fighter, Rogue, Wizard, Monk, Paladin, Ranger) while keeping
**spells in a separate table**.[^class-feature-rb] It `belongs_to
:player_class` and `has_many :class_feature_unlocks` (see
[class-feature-unlock.md](/models/class-feature-unlock.md)).

`action_type` (`passive`/`action`/`bonus_action`/`reaction`/`no_action`/`special`)
covers both passive and active abilities; `resource_name` +
`recharge_type` (`none`/`short_rest`/`long_rest`/`short_or_long_rest`/`turn`/
`round`/`special`) cover rest-based resources; `grants_spellcasting` flags
abilities that grant casting (e.g. a Wizard's `Spellcasting`) without storing
spells here.[^class-feature-rb] A casting feature carries the ability it casts
with in `spellcasting_ability` (`intelligence`\|`wisdom`\|`charisma`): a subclass
whose class has no ability of its own — the Fighter's Eldritch Knight, INT —
sets it here, and validation requires it unless the class already supplies one
(`PlayerClass#spellcasting_modifier`). See
[PlayerCharacter#spellcasting_ability](/models/player-character.md) for the
resolved value.

`slug` is the stable key code and seeds use to reference a feature — unique
per class (`index_class_features_on_player_class_id_and_slug`).

# Features the simulator knows by name

A few features have no effect payload the simulator could run: it applies
their rules itself, through [Combat::FeatureBook](/architecture/combat-simulator-service.md).
They are recognised by name, and the names live only here, as constants with
one predicate each: `COMBAT_SUPERIORITY` (`combat_superiority?`, the
superiority-dice pool), `ACTION_SURGE` (`action_surge?`), `WAR_MAGIC`
(`war_magic?`), `IMPROVED_WAR_MAGIC` (`improved_war_magic?`),
`ELDRITCH_STRIKE` (`eldritch_strike?`) and `INDOMITABLE` (`indomitable?`).
`Gambit#action_surge?` uses the same predicate. Phase 5.2 of the DDD refactor
replaces the names with a slug or capability, in this one place.
`maneuver_of?(combat_superiority)` tells a maneuver: a feature paid from that
feature's resource.[^class-feature-rb]

# Schema

| Field | Type | Description |
|-------|------|-------------|
| player_class_id | integer (FK) | → `player_classes` |
| name | string | e.g. `Second Wind`, `Rage`, `Ki` |
| slug | string | Unique per class |
| description | text | Functional description |
| feature_type | enum | `core`\|`optional`\|`subclass`\|`subclass_progression` |
| action_type | enum | `passive`\|`action`\|`bonus_action`\|`reaction`\|`no_action`\|`special` |
| resource_name | string | Optional, e.g. `Ki` |
| recharge_type | enum | `none`\|`short_rest`\|`long_rest`\|`short_or_long_rest`\|`turn`\|`round`\|`special` |
| grants_spellcasting | boolean | Marks casting-granting features |
| spellcasting_ability | enum | `intelligence`\|`wisdom`\|`charisma`; optional, overrides the class's ability for this feature |
| source_book | string | Default `PHB 2014` |
| source_reference | string | Optional short reference |
| notes | text | Optional |

[^class-feature-rb]: Source: `app/models/class_feature.rb`
