---
type: Model
title: PlayerClass
description: A D&D 5e class definition (hit die, spellcasting modifier) that anchors level progression and class features; looked up per level via progression_at, with no in-memory freezing.
resource: app/models/player_class.rb
tags: [model, class, persistence]
generated:
  by: copilot-cli/claude-sonnet-5
  at: 2026-08-21T23:39:26Z
sources:
  - id: player-class-rb
    title: app/models/player_class.rb
    resource: ../../app/models/player_class.rb
status: stable
---

# Overview

`PlayerClass` defines a D&D 5e class: its hit die (`d4`..`d12`, determines HP
gained per level) and its spellcasting modifier — currently enumerated as
`intelligence`/`wisdom`/`charisma` only (there is **no** `none` value in the
current enum, unlike earlier project documentation[^player-class-rb]); a non-caster
class simply leaves `spellcasting_modifier` unset.[^player-class-rb] It
`has_many :class_level_progressions, dependent: :destroy` (one row per
level 1-20, see [class-level-progression.md](/models/class-level-progression.md))
and `has_many :class_features, dependent: :destroy` (see
[class-feature.md](/models/class-feature.md)).[^player-class-rb]

There is **no `has_many :player_characters`** declared on this model today —
`PlayerCharacter belongs_to :player_class` is one-directional in the
association graph, even though the FK exists on
`player_characters`.[^player-class-rb]

`progression_at(level)` looks up the matching `ClassLevelProgression` with a
plain `find_by` — the previously-documented `freeze` on fetched progression
rows is not present in the current code; treat progression records as
ordinary (mutable) ActiveRecord objects.[^player-class-rb]

# Schema

| Field | Type | Description |
|-------|------|-------------|
| name | string | Class name, unique |
| hit_die | enum | `d4`\|`d6`\|`d8`\|`d10`\|`d12` |
| spellcasting_modifier | enum | `intelligence`\|`wisdom`\|`charisma`; unset for non-casters |
| description | text | Free text |

# HP growth

Level 1: `hit_die_value + CON_modifier`. Each level after: `+= roll(hit_die)
+ CON_modifier` — see [player-character.md](/models/player-character.md).
