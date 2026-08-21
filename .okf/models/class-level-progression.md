---
type: Model
title: ClassLevelProgression
description: The per-level table (1-20) of proficiency bonus, ability-score-improvement flag, and attacks-per-action for a PlayerClass; frozen in memory once loaded.
resource: app/models/class_level_progression.rb
tags: [model, class, progression, persistence]
generated:
  by: copilot-cli/claude-sonnet-5
  at: 2026-08-21T23:39:26Z
sources:
  - id: progression-rb
    title: app/models/class_level_progression.rb
    resource: ../../app/models/class_level_progression.rb
status: stable
---

# Overview

`ClassLevelProgression` `belongs_to :player_class` and holds one row per
level (1-20): the proficiency bonus at that level, whether the level grants
an ability score improvement, and how many attacks the class gets per Attack
action (`attacks_per_action`, default 1).[^progression-rb]

Every record is `freeze`d in an `after_find` callback, guaranteeing
progression data is immutable at runtime — safe to hand to combat code
without defensive copying.[^progression-rb] There is no `sorted` scope in the
current model; [PlayerClass#progression_at](/models/player-class.md) fetches
a single row directly by level rather than loading and sorting the whole
table.

Proficiency bonus follows the standard 5e table (+2 at levels 1-4, +3 at
5-8, +4 at 9-12, +5 at 13-16, +6 at 17-20).[^progression-rb] It feeds weapon
attack rolls; a code-implemented spell-save DC formula
(`9 + ability_modifier + proficiency_bonus`) was not found anywhere in the
codebase as of this writing — treat spell-save DC as **not yet
implemented**, not as a verified behavior.

`attacks_per_action` is what the Fighter's multiattack progression (1 attack
at levels 1-4, 2 at 5-10, 3 at 11-19, 4 at 20) is modeled with — it is data,
not special-cased code.

# Schema

| Field | Type | Description |
|-------|------|-------------|
| player_class_id | integer (FK) | → `player_classes` |
| level | integer | 1-20 |
| proficiency_bonus | integer | +2 to +6 |
| grants_ability_score_improvement | boolean | ASI at this level |
| attacks_per_action | integer | Default 1 |
