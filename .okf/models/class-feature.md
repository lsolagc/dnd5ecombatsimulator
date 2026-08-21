---
type: Model
title: ClassFeature
description: The identity and base behavior of a class ability (e.g. Second Wind, Rage, Ki) — action cost, resource, recharge rule — kept in a table separate from spells.
resource: app/models/class_feature.rb
tags: [model, class, feature, persistence]
generated:
  by: copilot-cli/claude-sonnet-5
  at: 2026-08-21T23:39:26Z
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
spells here.[^class-feature-rb]

`slug` is the stable key code and seeds use to reference a feature — unique
per class (`index_class_features_on_player_class_id_and_slug`).

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
| source_book | string | Default `PHB 2014` |
| source_reference | string | Optional short reference |
| notes | text | Optional |
