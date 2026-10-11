---
type: Decision
title: Combat action language — action, attack, effect
description: The project's vocabulary for what a combatant does in combat (action, Attack action, attack, effect), the decision to run the basic Attack action through the Combat::* pipeline, and the action economy it leaves open.
tags: [combat, evolution]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-11T00:00:00Z
verified: { by: human:lsolagc, at: 2026-10-11T18:27:39Z }
sources:
  - id: action-runner-rb
    title: app/services/combat/action_runner.rb
    resource: ../../app/services/combat/action_runner.rb
  - id: attack-action-test
    title: test/services/combat/attack_action_test.rb
    resource: ../../test/services/combat/attack_action_test.rb
status: stable
---

# Vocabulary

Decided with the user on 2026-10-11, when the basic attack moved into
[the Combat::* pipeline](/architecture/combat-effect-pipeline.md):

| Term | In code | Meaning |
|---|---|---|
| **Action** | `Combat::CombatAction` | What a combatant does with the action of its turn: Attack, cast a spell, use a feature; later Disengage, Dodge, Hide. |
| **Attack action** | `CombatAction(source_type: :attack)` | The action every combatant has, with the equipped weapon or bare fists. It holds `attacks_per_action` attacks (Extra Attack). |
| **Attack** | one weapon attack inside the Attack action | One attack roll against one target; on a hit it produces a damage effect. |
| **Effect** | `Combat::EffectInstance` | The atomic outcome of an action: damage or healing, with an optional attack roll or saving throw. |

The basic attack *has* an effect: weapon damage on a hit. That is why it
belongs in the pipeline rather than beside it. A spell attack such as Fire
Bolt already had exactly that shape, and keeping two paths had let the
weapon path apply resistances with the wrong damage type (see below).

# Decisions

- **The Attack action is one `CombatAction`**, with its multiattack inside
  it: `Combat::ActionRunner.attack` makes up to `attacks_per_action`
  attacks.[^action-runner-rb] Each attack asks for its own target, so an
  attack that follows a kill goes to another enemy instead of being lost;
  the action ends early only when no target is left.[^attack-action-test]
- **Target choice stays in the orchestrator.** Gambit rules, War Magic's
  focus and the random pick (with its own `@rng`) live in
  [CombatSimulatorService](/architecture/combat-simulator-service.md); the
  pipeline only asks for "the next target". So do the hooks around each
  attack: Distracting Strike advantage marks, the maneuver die on the first
  hit, and the Eldritch Strike mark.
- **War Magic's bonus attack uses the same Attack action**, although in 5e
  it is a bonus action. It is the known gap in the next section.
- **The legacy pair stays for now.** `PlayerCharacter#roll_an_attack`,
  `#get_attacked` and `Dice::AttackRoll` are no longer called by the
  simulator, but they were kept at the user's request. The user wants a
  walkthrough of what replaces each of them before they are removed.

# Open: the action economy

The user's intent is for the simulator to model 5e's action economy. That
is a project milestone. Today every turn spends exactly one "action", and
several things are modelled wrongly because of it:

- **Bonus actions:** Second Wind spends the whole turn, and War Magic's
  attack reuses the Attack action.
- **Riders:** Battle Master maneuvers (and later a Paladin's Smite) are
  choices added to an attack after Attack was chosen, consuming no action.
  Today they are offered as alternatives to Attack.
- **Extra actions:** Action Surge must grant one more action.
- **Reactions:** none are modelled yet.

Until that milestone, `CombatAction` means "whatever the simulator lets a
combatant do on its turn", not strictly the action slot.

# Validation

The migration was checked against recorded logs. 2,385 seeded combats (every
pair of development characters plus 2v2s, with level variants for Extra
Attack, War Magic and Champion crit ranges) and 180 combats with Distracting
Strike advantage produced byte-identical logs before and after. The weapon
attack makes the same dice draws in the same order: a d20, a second d20 with
advantage, then the damage dice.

**Fixed along the way:** the legacy `get_attacked` applied resistances using
the **defender's** own weapon damage type. The pipeline applies the effect's
type, which is the attacker's weapon. This changes results only when the
two types differ and the defender has a resistance, immunity or
vulnerability to one of them.

Measured on 2,000 combats of a level-5 Thorin (bludgeoning) against
slashing Fighters:

- **Resistance:** a Thorin resistant to slashing now halves their attacks.
  Combats against him last 1.2–1.9× longer (e.g. Brenna 1.60 → 3.02 rounds).
- **Vulnerability:** a Fighter vulnerable to bludgeoning is now hit for
  double damage. Thorin's damage is too small for this to show.

476 of the 2,000 combats changed. Win rates did not move, because Thorin
loses every one of these matchups.

[^action-runner-rb]: Source: `app/services/combat/action_runner.rb`

[^attack-action-test]: Source: `test/services/combat/attack_action_test.rb`
