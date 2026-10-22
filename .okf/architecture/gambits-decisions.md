---
type: Decision
title: Gambits — design decisions
description: The design decisions behind the FFXII-style gambits, grouped by subject (evaluation, which features are gambit actions, Action Surge and War Magic, batch log, gambits screen, presets, dev characters), each with its reason. Taken during the autonomous build, reviewed by the user on 2026-10-11.
tags: [combat, gambits]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-18T00:00:00Z
verified: { by: human:lsolagc, at: 2026-10-11T20:38:56Z }
sources:
  - id: issue-41
    title: "GitHub issue #41: gambit targets filtered by action, and an \"Outro aliado\" target"
    resource: https://github.com/lsolagc/dnd5ecombatsimulator/issues/41
  - id: issue-39
    title: "GitHub issue #39: D&D 5e action economy in the simulator"
    resource: https://github.com/lsolagc/dnd5ecombatsimulator/issues/39
  - id: issue-42
    title: "GitHub issue #42: a resource condition that names the resource"
    resource: https://github.com/lsolagc/dnd5ecombatsimulator/issues/42
  - id: issue-43
    title: "GitHub issue #43: rename the gambit condition to criterion in code and UI"
    resource: https://github.com/lsolagc/dnd5ecombatsimulator/issues/43
  - id: issue-44
    title: "GitHub issue #44: gambit preset CRUD (list, edit, delete)"
    resource: https://github.com/lsolagc/dnd5ecombatsimulator/issues/44
status: stable
---

# Context

Affects [Combat::Simulator](/architecture/combat-simulator.md) turn choice and [simulation batches](/architecture/simulation-batches.md) logs. The model is [Gambit](/models/gambit.md); the measured effect is in the [impact report](/architecture/gambits-impact.md); the vocabulary (criterion, status) is in the [ubiquitous language](/ubiquitous-language.md).

The gambits were built in an autonomous task. The user had already decided a few things in the task text: no gambit enabled means random; gambits but none fires means idle; presets are copies both ways; one polymorphic `gambits` table; the condition enum lives in code. Everything below was decided by the agent during the build and reviewed by the user on 2026-10-11. No decision was vetoed; the user's caveats are recorded in the rows they qualify.

# FFXII reference (research summary)

- A gambit = target+condition ("Ally: HP < 70%") + action ("Cure") + its slot
  (priority). Slots are an ordered list; each slot has an on/off toggle.
- Evaluated top to bottom whenever the character is ready to act; the first slot
  whose condition finds a valid target and whose action can be performed (MP,
  ability known) runs. A slot with no valid target or no resource is skipped.
- Targets are Self, Ally (the party, self included) or Foe.
- Nothing fires → the character stands idle. Player commands outrank gambits.
- Slots are unlocked through the License Board (up to 12) and reordered in the menu.

Simplifications here: 6 slots, no license unlocks, no player commands, one
condition per slot, conditions limited to what the simulator can observe.

# Evaluation

| Question | Decision | Why |
|---|---|---|
| Slots with gaps (FFXII allows empty slots between rules)? | Compact list: positions 1..n, n ≤ 6; the UI shows 6-n empty slots after the rules. | An empty slot is skipped anyway, so gaps carry no behavior; compact positions keep reorder a permutation. |
| Several valid targets — which one? | Candidates are walked in initiative order; the first that satisfies the condition wins (selector conditions take the min/max, ties by initiative order). | Task requires a fixed criterion, never a draw; initiative order is already seeded and deterministic. |
| Does "Aliado" include the actor? | Yes. | Same meaning as the existing payload `"ally"` target and FFXII's Ally. Caveat: 5e abilities that exclude the user (Bardic Inspiration, Commander's Strike) would make one label mean two things; [issue #41](https://github.com/lsolagc/dnd5ecombatsimulator/issues/41) plans a separate "Outro aliado" target and a target select filtered by action.[^issue-41] |
| Can any target be paired with any action? | No: validated against the action's natural target. Attack and enemy payloads → Inimigo; `self` payloads → Self (Action Surge included); `ally` payloads → Aliado or Self. | Avoids rules that can never fire or would heal an enemy. |
| A rule references an action the character lacks (e.g. preset from another subclass)? | Valid record; skipped at runtime as "action unavailable". | Lets presets be applied across characters, like FFXII skipping an unknown ability. |
| An action with several attacks loses its target mid-action? | The remaining attacks re-run the rule's target pick; if nothing qualifies, the first living enemy in initiative order. | 5e lets the fighter switch targets; stopping would waste attacks. |
| RNG draws for gambit-driven actors? | A gambit-driven choice consumes no `@rng` draw (no `sample`). Random-mode actors keep the exact same draw sequence. | Determinism of existing simulations and tests. |
| Gambits with all slots disabled? | Same as no gambits: random. | Task decision "sem nenhum gambit ligado". |
| Which payload decides a class feature's natural target? | The feature's effect at the owner's level, `ClassFeature#action_payload_at`, the function the simulator uses: a character's rule at its level, a preset's (no level) at the feature's highest unlock with a payload. An unlock without a payload inherits the one before it. Payloads with a `trigger` (passives) or a kind other than heal/damage are rejected. A feature with no effect yet at the owner's level is an action the owner lacks: checked like a preset's and skipped at runtime. Applying a preset whose rule does not hold at the character's level refuses the whole preset, naming the rule. | Validation and execution read the same effect, so a rule never targets what the character's level does not have; the user chose refusing the preset over skipping or flagging the rule. Part 3 of [issue #41](https://github.com/lsolagc/dnd5ecombatsimulator/issues/41).[^issue-41] |
| What is a "status" condition? | The only status the simulator tracks is the Distracting Strike advantage mark: `marked` = the target carries a mark the actor would use (from someone else), `unmarked` = it does not. | No other condition/status system exists; marks expire at their owner's next turn start, so the owner never sees its own mark. Note: "condition" here is the gambit rule's test, now called **criterion**, and "status" is anything with a duration on a combatant; see the [ubiquitous language](/ubiquitous-language.md). The rename in code and UI is [issue #43](https://github.com/lsolagc/dnd5ecombatsimulator/issues/43).[^issue-43] |
| "Resource available" condition? | `resource_at_least N`: the actor's remaining resource **for the rule's own action** is ≥ N (feature uses, the superiority-dice pool for maneuvers, slots of the spell's level). Rejected for Ataque and cantrips. The target is the first candidate in initiative order. | Availability (≥ 1) is already implied by the action check; the parameter lets a rule keep a reserve (e.g. "dados ≥ 2 → Precision Attack"). Caveat: once a character can hold several pools (multiclass, e.g. superiority dice and ki), the condition should name the resource ("Self: [recurso] ≥ N", like FFXII's "Self: MP ≥ X%", which never needs a name because MP is the only pool), defaulting to the action's own resource. Not needed today: a character has one class and no natural rule crosses its pools. Tracked, not planned soon, in [issue #42](https://github.com/lsolagc/dnd5ecombatsimulator/issues/42).[^issue-42] |

# Which features are gambit actions

Inventory of the Fighter's existing features (the only class with features today):

- **Chosen by a gambit** (turn actions): Ataque; Second Wind; Action Surge; the 5 maneuvers
  with an effect (Precision, Disarming, Lunging, Sweeping, Distracting Strike); the 5 spells
  with an effect (Fire Bolt, Ray of Frost, Chromatic Orb, Scorching Ray, Fireball).
- **Automatic, not a turn choice** (stay as they are): Indomitable (reaction to a failed
  save), War Magic / Improved War Magic (bonus attack after a spell), Eldritch Strike (mark
  on hit), Survivor (turn-start heal), fighting styles and Improved/Superior Critical
  (always-on modifiers), Combat Superiority (the dice pool maneuvers spend).
- **Not executable in the simulator** (no effect payload), so not offered: the 13 other
  maneuvers, Great Weapon Fighting / Protection / Two-Weapon Fighting, Remarkable Athlete,
  Additional Fighting Style, Student of War, Know Your Enemy, Improved Combat Superiority,
  Relentless, Weapon Bond, Arcane Charge, Shield, Stoneskin.

| Question | Decision | Why |
|---|---|---|
| Should reactions and passives (Indomitable, War Magic, Eldritch Strike) be gambit actions? | No — they stay automatic. | FFXII gambits only pick the turn's action; reactions fire on their own. "Every feature can be fired by a gambit" is read as every *turn action*. Caveat: anything the player chooses to use gets a gambit eventually (reactions like opportunity attacks and Counterspell, War Magic's bonus attack, Indomitable's single use); only always-on effects stay automatic. Planned with the action economy in [issue #39](https://github.com/lsolagc/dnd5ecombatsimulator/issues/39).[^issue-39] |
| Inventory tests on fixtures or real content? | Real content: each test loads `db/seeds` (SeedData.load_all, inside the test transaction) and fires the feature through a single gambit. | Proves reachability with the content the user actually runs, not a fixture double. |

# Action Surge and War Magic

| Question | Decision | Why |
|---|---|---|
| How does Action Surge fit an FFXII rule? | It is a gambit action (target Self). When its rule wins, one use is spent, a marker turn is logged, and the actor evaluates its gambits twice more (normal action, then `extra: true`); Action Surge rules are skipped inside those two. | Lets the user decide *when* to surge (e.g. "Self: HP < 50% → Action Surge"), and the two actions still follow the list. |
| Does a gambit-driven actor still get the automatic random Action Surge? | No: only through a rule. Random-mode actors keep the automatic one. A gambit-driven Fighter with no Action Surge rule never surges. | The "automatic random Action Surge" is what an actor without gambits does: right after its normal action, on the first turn it has a use left, it takes one extra action drawn at random. An early version gave it to gambit-driven actors too, so a Fighter whose list matched nothing stood idle and then still acted at random through the surge. FFXII never acts outside the list, and a rule lets the user choose *when* to surge instead of always on the first turn. |
| How does the simulator know an Action Surge rule? | `Gambit#action_surge?`: the feature's effect is an `extra_action` (like `Combat::FeatureBook#unlock_with("extra_action")`, since phase 5.2; a name check before); available while unlocked with uses > 0 and not already inside a surge. | One kind check, shared with the existing automatic surge. |
| An evaluation inside an Action Surge finds no rule? | It logs an idle entry; the one for the extra action carries `extra: true`. | Keeps "the list ran twice" visible in the log. |
| The fight ends during a surge or before War Magic's bonus? | The remaining evaluation and the bonus attack are skipped (no entry). | Same as the random `action_surge_turn`, which returns nil once combat is over. |
| War Magic bonus attack target for a gambit-driven actor? | The spell's target if it is a living enemy, else the first living enemy in initiative order; no `@rng`. | It stays automatic, but must be deterministic like every other gambit choice. Caveat: this works only because the simulator has no range or reach. A cantrip can hit a distant enemy that a weapon cannot reach, and 5e does not require the bonus attack to hit the spell's target, so once range exists the bonus attack needs its own target pick. |

# Batch copy and log

| Question | Decision | Why |
|---|---|---|
| When is the gambits copy taken? | When the batch is created: a `gambit_settings` jsonb column on `simulation_batches`, keyed by character id like `combatant_settings`, filled once (missing keys only). Every run of the batch is **simulated from that copy**, not from the database. | One copy per batch keeps every run of an experiment on the same rules, and running from the copy (not only logging it) means an edit mid-batch can't make the log lie. |
| "Repetir com ajustes" (rerun)? | Does not copy the gambits; the new batch snapshots the characters' current rules. | Gambits are not editable in the experiment builder, only on the character; repeating after editing them is the point. |
| Shape of the per-combatant section? | Per side, per combatant: `mode` ("gambits" or "aleatório") and every rule in priority order with position, on/off, target, condition, action and the full readable rule. All-disabled rules are listed with mode "aleatório". | The task asks for target, condition, action and on/off per rule; the mode makes the random fallback explicit. |
| Which turn entries carry the fired gambit? | Every decision entry: `{ position, rule }`, `"nenhum aplicável: parado"` or `"aleatório"`. A War Magic bonus inherits the gambit of the spell turn that triggered it; turn-start/turn-end passives carry none. | Passives and the bonus are not decisions; inheriting keeps the bonus traceable to its rule. |
| Where does the section sit in the log? | Once, in the header of the batch's single JSON log (since 2026-10-17, phase 2.1 of the DDD refactor), under each combatant of `parties` next to its frozen name and settings; the simulations no longer repeat it. (Before, every `simulation-NNNN.json` of a zip opened with it, right after `simulation`, `seed` and `elapsed_ms`.) | The section comes from the batch's copy, identical for every run: repeating it per simulation only grew the file. |

# Gambits screen

| Question | Decision | Why |
|---|---|---|
| Where does the screen live? | Its own page, `/player_characters/:id/gambits` (nested `resources :gambits`), linked by a "Gambits" button on the character sheet, which also lists the enabled rules read-only. | The sheet is already long; FFXII keeps gambits on their own menu screen. |
| Save model? | Each slot saves on its own (one form per filled slot, PATCH); an empty slot is a "new rule" form (POST, next position). Toggle, up/down and delete are small `button_to` forms, so everything works without JS. | Matches the per-row FFXII editing; no client-side state to lose. |
| Drag and drop? | Native HTML5 DnD in a Stimulus controller (`gambits_controller.js`), which on drop sends the new id order to `PATCH .../gambits/reorder`; the server rewrites every position in one transaction (unique constraint deferred). Up/down buttons are the keyboard path. SortableJS not added. | The task asks to try native first; the list is ≤ 6 rows, native DnD is enough. |
| Which actions are offered? | The character's own turn actions (the inventory above, filtered to it): Ataque, unlocked Second Wind/Action Surge, known maneuvers with an effect, known spells with an effect. A rule pointing elsewhere (e.g. after a preset) still shows its action, marked "indisponível". | Offering everything would make rules that can never fire; keeping foreign rules visible avoids silent data loss. |
| Invalid combinations (target/condition vs action)? | Server-side validation; the slot re-renders with the error. Stimulus only hides the value input when the condition takes none. | The model already validates; duplicating rules in JS is drift risk. |
| How does the switch work without JS? | A `button_to` with `role="switch"`/`aria-checked`, reading "● Ligado" / "○ Desligado". | A checkbox would need JS to submit; a button inside a form works everywhere. |
| A hidden value field with a stale number? | Stimulus also disables it, and `GambitsController#gambit_params` clears `condition_value` whenever the submitted condition is not in `Gambit::CONDITIONS_WITH_VALUE`. | Without the clearing, switching "HP abaixo de 40" to "Qualquer" never saved (the stored 40 failed the absence validation). |
| Concurrent writes to positions? | `create`, `move`, `destroy` (with its renumbering) and `reorder` run in one transaction holding `lock!` on the character; every position is rewritten. Not covered by a real concurrency test. | Two requests reading the same positions could otherwise write duplicates or gaps. |
| Malformed input to `move`/`reorder`? | `direction` other than up/down and `ids` that are not a list of digit strings answer 422 (`"12abc"` is refused, not read as 12). | A tampered request must not 500 nor be read as "down". |
| Order of the action options? | Ataque, then features by unlock level and name, then spells by level and name (`PlayerCharacter#gambit_action_options`, values from `Gambit#action_choice`). | Deterministic select order; the preset panel reuses both. |
| Where does a refused 7th gambit show its error? | An alert above the list (the new-rule form is not rendered with 6 rules). | There is no empty slot to attach it to. |
| A drop the server refuses (stale page)? | The page reloads anyway and shows the stored order. | The server is the truth; no client-side rollback. |
| All rules off, on the sheet? | The summary lists them dimmed plus "Todos desligados: ação aleatória." | Otherwise the sheet would suggest the rules still drive the turn. |

# Presets

| Question | Decision | Why |
|---|---|---|
| Model? | `gambit_presets` (`name` unique, case-insensitive, stripped), `has_many :gambits, as: :owner, dependent: :destroy`, reusing the `gambits` table, validations and labels. | Task decision: same table, same validations. |
| Where is the preset UI? | A "Presets" panel on the character's gambits screen: "Salvar como preset" (new name, or overwrite a chosen one) and "Aplicar preset" (select + confirm). No preset index or editor screen. | "Editar um preset fora de um personagem" is out of scope; everything starts from a character. Caveat: the user wants a preset CRUD eventually (list, edit screen, delete); tracked, not planned soon, in [issue #44](https://github.com/lsolagc/dnd5ecombatsimulator/issues/44).[^issue-44] |
| Where do the preset actions live? | Collection routes on the character's gambits (`save_preset`, `overwrite_preset`, `apply_preset`) in `GambitsController`, reusing its character scoping and screen loading; no `GambitPresetsController`. | A refusal re-renders the gambits screen (422) with the error in the panel; a second controller would duplicate `load_screen`. |
| Copy semantics? | Save and apply both delete the destination's rules and insert copies (position, enabled, target, condition, value, action), in one transaction; no link is kept. | Task decision: copy both ways. |
| Positions of the copies? | Renumbered 1..n in the source's priority order, not copied verbatim. | Same result for compact sources; a source with gaps still yields a valid compact list. It also makes the order of the copy observable (and testable). |
| Saving a character with no rules? | Refused ("sem regras para salvar"). | An empty preset would wipe characters it is applied to. |
| Overwriting from a character with no rules? | Refused like saving ("sem regras para salvar"); the preset keeps its rules. | Same reason as saving: an empty preset would wipe characters. |
| Applying a preset with an action the character lacks? | Copied anyway; the screen shows it "(indisponível)" and the simulator skips it. | Same rule as any rule whose action the character lacks; presets are meant to travel between characters. |
| Overwrite confirmation? | `turbo_confirm` on overwrite and apply ("substitui as N regras atuais"). | Both are destructive for the destination. |
| Missing or malformed `preset_id`? | Unknown id → 404; absent or non-scalar → 400 (`params.expect`). Never 500. | Same style as the rest of the controller. |
| Two concurrent saves with the same name? | The unique index on `lower(name)` refuses the second, and the controller rescues `RecordNotUnique` into the same 422 as a duplicate name. | A race between two tabs must not 500; the validation covers every non-concurrent case. |

# Dev characters: Brenna and Corwin

Both are level-4 Fighters in the dev database only (not in the YAML seeds): Brenna
Ironhide (id 17, Champion, Great Weapon Fighting) and Corwin Vale (id 18, Battle Master,
Dueling, knows Disarming Attack, Distracting Strike and Precision Attack).

| Question | Decision | Why |
|---|---|---|
| How are they configured? | `bin/rails gambits:brenna_corwin` (lib/tasks/gambits.rake, logic and rules in `GambitSetups`, lib/gambit_setups.rb): finds each by exact name, replaces only that character's gambits in one transaction, aborts with a message if a name or a feature is missing. Idempotent by construction (replace, not append). | Task: idempotent, by name, touching nothing else. |
| Brenna (defensive) | 1 Self: HP < 50% → Second Wind · 2 Self: HP < 50% → Action Surge · 3 Inimigo: menor HP → Ataque · 4 (desligada) Self: qualquer → Action Surge | Heals before anything when hurt, then surges while hurt to close the fight; the disabled rule shows the toggle and the "surge at once" alternative. Rule 2 was planned as "Inimigo: HP < 30% → Action Surge", but the model rejects it (Action Surge only takes the Self target, `Gambit::COMPATIBLE_TARGETS`); "Self: HP < 50%" is the closest valid rule. Once Second Wind is spent, rule 1 is skipped and rule 2 fires. |
| Corwin (aggressive) | 1 Self: qualquer → Action Surge · 2 Inimigo: recurso ≥ 2 → Precision Attack · 3 Self: HP < 25% → Second Wind · 4 Inimigo: menor HP → Disarming Attack · 5 (desligada) Inimigo: não marcado → Distracting Strike · 6 Inimigo: menor HP → Ataque | Surges on the first turn, spends dice on Precision while keeping one back for Disarming (the last die), heals only when nearly down. Distracting Strike's mark only helps other attackers (`marked_for?` ignores the actor's own mark), so enabled in a 1x1 it won every turn and swallowed the pool (Precision and Disarming fired 0 times in 300 seeds); it stays disabled, ready for group fights. |

# Known limitations

- A tampered request can store a rule whose action is outside the character's options. It is consistent with "(indisponível)" rules and presets, and the simulator skips it.
- The position writes hold a row lock (see "Concurrent writes to positions?") but no test exercises real concurrency.

[^issue-41]: Source: GitHub issue #41: gambit targets filtered by action, and an "Outro aliado" target

[^issue-39]: Source: GitHub issue #39: D&D 5e action economy in the simulator

[^issue-42]: Source: GitHub issue #42: a resource condition that names the resource

[^issue-43]: Source: GitHub issue #43: rename the gambit condition to criterion in code and UI

[^issue-44]: Source: GitHub issue #44: gambit preset CRUD (list, edit, delete)
