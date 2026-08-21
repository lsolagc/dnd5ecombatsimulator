---
type: Model
title: Combatant
description: The actual in-combat "character sheet" — ability scores, armor class, speed, proficiency bonus, and resistance/vulnerability/immunity maps — attached polymorphically to a combatable (today, only PlayerCharacter).
resource: app/models/combatant.rb
tags: [model, combat, persistence]
generated:
  by: copilot-cli/claude-sonnet-5
  at: 2026-08-21T23:39:26Z
sources:
  - id: combatant-rb
    title: app/models/combatant.rb
    resource: ../../app/models/combatant.rb
  - id: condition-logic-rb
    title: app/models/concerns/condition_and_damage_type_logic.rb
    resource: ../../app/models/concerns/condition_and_damage_type_logic.rb
status: stable
---

# Overview

`Combatant` holds every stat combat mechanics read: the six ability scores,
`armor_class` (default 10), `speed` (default 30), `proficiency_bonus`
(default 2), and `max_hit_points` (default 1) — plus `resistances`,
`vulnerabilities`, and `immunities` as nested jsonb maps keyed by
`"conditions"` and `"damage_types"` (each a fixed set of D&D 5e condition
and damage-type keys, default `false`).[^combatant-rb] This is the opposite
of what the legacy data-model doc describes: ability scores and defenses are
**not** on `PlayerCharacter` — they are here, and `PlayerCharacter` reaches
them by delegation (see [player-character.md](/models/player-character.md)).

It uses `delegated_type :combatable, types: %w[ PlayerCharacter ]` rather
than the older `belongs_to :combatable, polymorphic: true` — Rails'
delegated-type pattern, which still supports adding non-`PlayerCharacter`
combatants later without a schema change, but resolves the concrete type
through `combatable_type`/`combatable_id` plus a generated `player_character`
reader rather than a raw polymorphic association.

**In-combat current HP is not stored here.** `current_hit_points` lives as
a transient `attr_accessor` on the `combatable` (`PlayerCharacter`) via the
`CombatantBehavior` concern, reset from this record's `max_hit_points` at
the start of an encounter — see
[player-character.md](/models/player-character.md).

`immune_to?`/`resistant_to?`/`vulnerable_to?` look up
`resistances/vulnerabilities/immunities.dig("damage_types"|"conditions",
key)`; `PlayerCharacter#take_damage` calls these before applying
damage.[^condition-logic-rb] This is the opposite of what earlier project
documentation described — resistances/vulnerabilities/immunities are
`Combatant` columns, not `PlayerCharacter` ones.[^combatant-rb]

# Schema

| Field | Type | Description |
|-------|------|-------------|
| combatable_type / combatable_id | string / integer | Delegated type — today always `PlayerCharacter` |
| strength / dexterity / constitution / intelligence / wisdom / charisma | integer | Ability scores, default 10 |
| armor_class | integer | Default 10 |
| speed | integer | Default 30 |
| proficiency_bonus | integer | Default 2 |
| max_hit_points | integer | Default 1 |
| resistances / vulnerabilities / immunities | jsonb | `{ "conditions" => {...}, "damage_types" => {...} }`, all keys default `false` |
