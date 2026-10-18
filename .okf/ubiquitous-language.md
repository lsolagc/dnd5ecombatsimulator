---
type: Glossary
title: Ubiquitous language
description: The project's agreed vocabulary in one place (action, Attack action, attack, effect, feature book; condition, status, criterion), with each term's name in code and its meaning, so code, UI and docs use the same words.
tags: [combat, gambits]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-18T00:00:00Z
verified: { by: human:lsolagc, at: 2026-10-11T21:31:58Z }
sources:
  - id: issue-43
    title: "GitHub issue #43: rename the gambit condition to criterion in code and UI"
    resource: https://github.com/lsolagc/dnd5ecombatsimulator/issues/43
---

# How to use this page

Every term the project agreed on with the user lives here, and only here.
Other concepts link to this page instead of redefining a term. When a term
changes, change it here and log it.

# Actions

Agreed on 2026-10-11, when the basic attack moved into
[the Combat::* pipeline](/architecture/combat-effect-pipeline.md). The
decisions behind it are in
[Combat action language](/architecture/combat-action-language.md).

| Term | In code | Meaning |
|---|---|---|
| **Action** | `Combat::CombatAction` | What a combatant does with the action of its turn: Attack, cast a spell, use a feature; later Disengage, Dodge, Hide. |
| **Attack action** | `CombatAction(source_type: :attack)` | The action every combatant has, with the equipped weapon or bare fists. It holds `attacks_per_action` attacks (Extra Attack). |
| **Attack** | one weapon attack inside the Attack action | One attack roll against one target; on a hit it produces a damage effect. |
| **Effect** | `Combat::EffectInstance` | The atomic outcome of an action: damage or healing, with an optional attack roll or saving throw. |
| **Action option** | `Combat::ActionOption` | One action the simulator offers an actor this turn (Attack, a feature or maneuver, a spell, Action Surge), before it runs. A gambit's pick is the same option with the rule's target and gambit. Not an Action: running it builds the `CombatAction`. |
| **Rider** | today the `rider` key of an attack, maneuvers only; `Combat::Rider` in phase 3.3 | An effect that rides along on an **attack**: chosen with the action or triggered by it, applied when the attack hits, on top of the attack's own damage. Today the Battle Master maneuvers (their die and, for Distracting Strike, the advantage mark); later Divine Smite, Sneak Attack, Hunter's Mark. An attack can carry several. Agreed on 2026-10-18 as attack-only: whether something can ride on a spell or a feature is decided when the first such case arrives. |
| **Feature book** | `Combat::FeatureBook` | What a combatant knows how to do in a simulation: its unlocked features, which of them are actions, the ones the simulator runs by rules of its own (Action Surge, War Magic, Eldritch Strike, Indomitable), whose uses each spends and the uses it starts with. Read-only: the uses left are combat state, not part of the book. |
| **Turn record** | `Combat::TurnRecord` | One entry of a round's turns in the `round_log`: who acted, the action, its effects and the gambit behind it. |

# Conditions, status and criteria

Agreed on 2026-10-11. "Condição" used to mean two things: a 5e condition
and the test in a [gambit](/models/gambit.md) rule.

| Term | In code | Meaning |
|---|---|---|
| **Condition** (condição) | `immunities["conditions"]` (also in `resistances`/`vulnerabilities`) | Only the 15 official 5e conditions: poisoned, stunned, paralyzed, and so on. Nothing applies a condition yet. |
| **Status** | none yet; the only ones tracked are the Distracting Strike advantage marks (`@advantage_marks`) | Anything on a combatant that lasts for a duration: a condition, a buff or debuff that is not a condition (Bless), the Distracting Strike or Eldritch Strike mark. A condition is one kind of status. |
| **Criterion** (critério) | `Gambit#condition` today, to be renamed `criterion`[^issue-43] | The test in a gambit rule: `any`, `hp_below`, `marked`, `resource_at_least`, and so on. |

Words avoided on purpose: **trigger** (gatilho) already names a passive
effect's `trigger` in the payload, and **check** (teste) collides with
saving throws and ability checks.

[^issue-43]: Source: GitHub issue #43: rename the gambit condition to criterion in code and UI
