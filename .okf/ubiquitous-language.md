---
type: Glossary
title: Ubiquitous language
description: The project's agreed vocabulary in one place (action, Attack action, attack, effect, rider, action cost, feature book, combatant, participant, encounter, simulator, gambit policy, turn executor; effect kinds; condition, status, criterion), with each term's name in code and its meaning, so code, UI and docs use the same words.
tags: [combat, gambits]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-19T00:00:00Z
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
| **Attack action** | `CombatAction(source_type: :attack)` | The action every combatant has, with the equipped weapon or bare fists. It holds `attacks_per_action` attacks (Extra Attack). War Magic's bonus is not one: it is a single weapon attack. |
| **Attack** | one weapon attack inside the Attack action | One attack roll against one target; on a hit it produces a damage effect. |
| **Effect** | `Combat::EffectInstance` | The atomic outcome of an action: damage or healing, with an optional attack roll or saving throw. |
| **Action option** | `Combat::ActionOption`, listed by `Combat::Participant#action_options` | One action an actor can take this turn (Attack, a feature or maneuver, a spell; Action Surge is added by the **gambit policy**), before it runs. A gambit's pick is the same option with the rule's target and gambit. Not an Action: running it (`TurnExecutor#run`) builds the `CombatAction`. The participant lists them since phase 3.5. |
| **Rider** | `Combat::Rider` (`app/services/combat/rider.rb`); in the log, the `riders` list of the attack action (the riders chosen for it: `feature_slug`, `feature_name`) and of each attack (the riders it applied, empty on a miss: the feature, its effect when it has one, `statuses` when it applied any); the `rider` effect kind (Eldritch Strike) | An effect that rides along on an **attack**: chosen with the action or triggered by it, applied when the attack hits, on top of the attack's own damage. Today the Battle Master maneuvers (their die and, for Distracting Strike, the `next_attack_advantage` **status**) and Eldritch Strike (`kind: rider`, `event: weapon_hit`: the hit leaves disadvantage on the target's next save against the attacker's spells); later Divine Smite, Sneak Attack, Hunter's Mark. An attack can carry several. Agreed on 2026-10-18 as attack-only: whether something can ride on a spell or a feature is decided when the first such case arrives. |
| **Action cost** | the `as` of a `grants_activity` (`action` \| `bonus_action` \| `reaction`, PHB terms) | What doing something takes from the turn's economy. Distinct from **Action** (the activity itself). Declared, not charged yet (issue #39). |
| **Feature book** | `Combat::FeatureBook` | What a combatant knows how to do in a simulation: its unlocked features, which of them are actions, the ones the simulator runs by rules of its own (read by effect kind: Action Surge, War Magic, Eldritch Strike, Indomitable), whose uses each spends and the uses it starts with. Read-only: the uses left are combat state, kept by the **participant**. |
| **Combatant** | `Combatant` (the record), and "a combatant" in prose | The sheet's combat stats (ability scores, AC, max HP, weapon, defenses), persisted; the parent of anything that fights (today `PlayerCharacter`). Never written by a simulation. |
| **Participant** | `Combat::Participant` | Who fights in one simulation, built from a sheet when it starts: owns current HP, spell slots left, uses left, the **statuses** it carries and its feature book, and reads everything else from the sheet (its `delegate` list is the contract another kind of combatant, a Monster, has to meet). |
| **Encounter** | `Combat::Encounter` (`app/services/combat/encounter.rb`) | The fight as a whole, one per simulation: the two parties of participants and the initiative order. Answers who is on whose side (`party_for`, `allies_of`, the participant included, `enemies_of`), who is standing (`alive`, `first_living_enemy` in initiative order) and whether it is `over?`; at the start of each turn (`start_turn`) it expires the statuses the actor applied that end then. Agreed on 2026-10-18 (phase 3.4). |
| **Simulator** | `Combat::Simulator` (`app/services/combat/simulator.rb`) | The combat orchestrator: one seeded fight from two parties of sheets. Builds the **encounter**, rolls initiative, runs the rounds and each turn's start and turn passives, and returns the result. Was `CombatSimulatorService` until phase 3.5 (2026-10-19). |
| **Gambit policy** | `Combat::GambitPolicy` (`app/services/combat/gambit_policy.rb`) | How a gambit-driven actor chooses, one per simulation: its enabled rules by priority (its own, or a batch's copy), the first one whose action is offered and whose **criterion** finds a target, and the log of the rule. Draws nothing random. Agreed on 2026-10-19 (phase 3.5). |
| **Turn executor** | `Combat::TurnExecutor` (`app/services/combat/turn_executor.rb`) | One actor's turn in an encounter: by the **gambit policy** or at random, chains Action Surge and War Magic, runs the actions through the pipeline and returns the **turn records**. Agreed on 2026-10-19 (phase 3.5). |

# Effect kinds

Agreed on 2026-10-18 (phase 5.2 of the DDD refactor). A feature's mechanics
are declared in its `effect_payload` by `kind`, from one finite vocabulary
(`ClassFeatureUnlock::EFFECT_KINDS`, see
[ClassFeatureUnlock](/models/class-feature-unlock.md)); the engine never reads a
feature's name. Besides `heal`, `damage` and `modifier`:

| Term | In code | Meaning |
|---|---|---|
| **Extra action** | `kind: extra_action` | One more action on the turn (Action Surge). |
| **Grants activity** | `kind: grants_activity` | `count` activities (`activity: weapon_attack`) at an **action cost** (`as`) once the turn's action did something (`after: { cast_with_action: cantrip \| any_spell }`): War Magic, Improved War Magic. |
| **Rider** (effect kind) | `kind: rider` | See **Rider** above: declared with `event`, `applies` and `against`. |
| **Reroll save** | `kind: reroll_save` | Reroll a saving throw `when: failed` (Indomitable). |
| **Resource pool** | `kind: resource_pool` | A shared pool of uses: every feature with the same `resource_name` spends it (Combat Superiority's superiority dice, paid by the maneuvers). |
| **Turn record** | `Combat::TurnRecord` | One entry of a round's turns in the `round_log`: who acted, the action, its effects and the gambit behind it. |

# Conditions, status and criteria

Agreed on 2026-10-11. "Condição" used to mean two things: a 5e condition
and the test in a [gambit](/models/gambit.md) rule.

| Term | In code | Meaning |
|---|---|---|
| **Condition** (condição) | `immunities["conditions"]` (also in `resistances`/`vulnerabilities`) | Only the 15 official 5e conditions: poisoned, stunned, paralyzed, and so on. Nothing applies a condition yet. |
| **Status** | `Combat::Status` (`kind`, `source`, `ends`), carried by the participant it is on (`Participant#add_status`, `#take_statuses`, `#status?`, `#expire_statuses!`); kinds in `Combat::Status::KINDS`; a maneuver payload's `statuses` | Anything on a combatant that lasts for a duration: a condition, a buff or debuff that is not a condition (Bless), the Distracting Strike or Eldritch Strike mark. A condition is one kind of status. Today two kinds: `next_attack_advantage` (Distracting Strike, `ends: source_turn_start`) and `disadvantage_on_next_save` (Eldritch Strike, no end of its own: used up only by the source's next spell at the carrier that calls for a save). One per kind and source on a carrier: the same source applying it again renews it. Conditions, durations in rounds and a gambit criterion on a status are issue #45. |
| **Criterion** (critério) | `Gambit#condition` today, to be renamed `criterion`[^issue-43] | The test in a gambit rule: `any`, `hp_below`, `marked`, `resource_at_least`, and so on. |

Words avoided on purpose: **trigger** (gatilho) already names a passive
effect's `trigger` in the payload, and **check** (teste) collides with
saving throws and ability checks.

[^issue-43]: Source: GitHub issue #43: rename the gambit condition to criterion in code and UI
