---
type: Decision
title: Gambits — decisions taken autonomously while building the FFXII-style turn AI
description: Refinement questions raised per pass of the gambits work (feat/gambits), with the decision taken and why, for the user to veto at the end.
tags: [combat, decision, gambits]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-08T23:50:00Z
status: draft
---

# Context

Affects [CombatSimulatorService](/architecture/combat-simulator-service.md) turn choice and [simulation batches](/architecture/simulation-batches.md) logs.

The gambits task ran autonomously (CLAUDE_AUTONOMOUS=1). Decisions the user had
already taken are in the task text (no gambit enabled = random; gambits but none
fires = idle; presets are copies both ways; polymorphic `gambits` table; condition
enum in code). Everything below was decided by the agent and is open to veto.

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

# Pass 1 — model and evaluator (POC)

| Question | Decision | Why |
|---|---|---|
| Slots with gaps (FFXII allows empty slots between rules)? | Compact list: positions 1..n, n ≤ 6; the UI shows 6-n empty slots after the rules. | An empty slot is skipped anyway, so gaps carry no behavior; compact positions keep reorder a permutation. |
| Several valid targets — which one? | Candidates are walked in initiative order; the first that satisfies the condition wins (selector conditions take the min/max, ties by initiative order). | Task requires a fixed criterion, never a draw; initiative order is already seeded and deterministic. |
| Does "Aliado" include the actor? | Yes. | Same meaning as the existing payload `"ally"` target and FFXII's Ally. |
| Can any target be paired with any action? | No: validated against the action's natural target. Attack and enemy payloads → Inimigo; `self` payloads → Self (Action Surge joins in pass 2); `ally` payloads → Aliado or Self. | Avoids rules that can never fire or would heal an enemy. |
| A rule references an action the character lacks (e.g. preset from another subclass)? | Valid record; skipped at runtime as "action unavailable". | Lets presets be applied across characters, like FFXII skipping an unknown ability. |
| An action with several attacks loses its target mid-action? | The remaining attacks re-run the rule's target pick; if nothing qualifies, the first living enemy in initiative order. | 5e lets the fighter switch targets; stopping would waste attacks. |
| RNG draws for gambit-driven actors? | A gambit-driven choice consumes no `@rng` draw (no `sample`). Random-mode actors keep the exact same draw sequence. | Determinism of existing simulations and tests. |
| Gambits with all slots disabled? | Same as no gambits: random. | Task decision "sem nenhum gambit ligado". |
| Which payload decides a class feature's natural target? | The highest-level unlock that has a payload; payloads with a `trigger` (passives) or a kind other than heal/damage are rejected. | Matches what the simulator offers as an action; a passive rule could never fire. |
| Gambits snapshot for batches? | Deferred to pass 3 (log): pass 1 reads `combatant.gambits` live. | Reviewer flagged that editing gambits mid-batch breaks seed reproduction; pass 3 fixes it with a snapshot the simulator runs from. |

**Pass 1 status (2026-10-09):** code complete and suite green, but the adversarial
review still blocks after 3 iterations, on test gaps only (a pinned test for the
random path, `any` drawing no `@rng`, a spell rule matching its own FK, and a
multi-rule determinism scenario). The user allowed 3 more iterations; iteration 4 closed those, iteration 5 covered priority-by-position after out-of-order creation and single spell-slot consumption; iteration 6 pinned the random path for casters and War Magic, and the review came back non-blocking. Committed.

# Pass 2 — coverage

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
| Should reactions and passives (Indomitable, War Magic, Eldritch Strike) be gambit actions? | No — they stay automatic. | FFXII gambits only pick the turn's action; reactions fire on their own. "Every feature can be fired by a gambit" is read as every *turn action*. |
| How does Action Surge fit an FFXII rule? | It is a gambit action (target Self). When its rule wins, one use is spent, a marker turn is logged, and the actor evaluates its gambits twice more (normal action, then `extra: true`); Action Surge rules are skipped inside those two. | Lets the user decide *when* to surge (e.g. "Self: HP < 50% → Action Surge"), and the two actions still follow the list. |
| Does a gambit-driven actor still get the automatic random Action Surge? | No: only through a rule. Random-mode actors keep the automatic one. | Fixes the pass-1 gap where an idle actor still acted at random; FFXII never acts outside the list. |
| War Magic bonus attack target for a gambit-driven actor? | The spell's target if it is a living enemy, else the first living enemy in initiative order; no `@rng`. | It stays automatic, but must be deterministic like every other gambit choice. |
| What is a "status" condition? | The only status the simulator tracks is the Distracting Strike advantage mark: `marked` = the target carries a mark the actor would use (from someone else), `unmarked` = it does not. | No other condition/status system exists; marks expire at their owner's next turn start, so the owner never sees its own mark. |
| "Resource available" condition? | `resource_at_least N`: the actor's remaining resource **for the rule's own action** is ≥ N (feature uses, the superiority-dice pool for maneuvers, slots of the spell's level). Rejected for Ataque and cantrips. The target is the first candidate in initiative order. | Availability (≥ 1) is already implied by the action check; the parameter lets a rule keep a reserve (e.g. "dados ≥ 2 → Precision Attack"). |
| Inventory tests on fixtures or real content? | Real content: each test loads `db/seeds` (SeedData.load_all, inside the test transaction) and fires the feature through a single gambit. | Proves reachability with the content the user actually runs, not a fixture double. |

Smaller choices taken while building pass 2:

| Question | Decision | Why |
|---|---|---|
| An evaluation inside an Action Surge finds no rule? | It logs an idle entry; the one for the extra action carries `extra: true`. | Keeps "the list ran twice" visible in the log. |
| The fight ends during a surge or before War Magic's bonus? | The remaining evaluation and the bonus attack are skipped (no entry). | Same as the random `action_surge_turn`, which returns nil once combat is over. |
| How does the simulator know an Action Surge rule? | `Gambit#action_surge?` (feature named "Action Surge", like `action_surge_unlock_for`); available while unlocked with uses > 0 and not already inside a surge. | One name check, shared with the existing automatic surge. |

**Pass 2 status:** code complete, suite green; every invariant proven by sabotage (scratchpad/build-p2).

**Pass 2 status (2026-10-09):** the review blocked three times on test gaps only (spell
slot level, War Magic fallback with several enemies, Action Surge uses under
`resource_at_least`). After iteration 3 the last gap was a single assertion the reviewer
had already validated; the orchestrator added it, proved `.first`, `.last` and
`sample(@rng)` red, and committed instead of stopping the task. Flagged for the user.

# Pass 3 — log

| Question | Decision | Why |
|---|---|---|
| When is the gambits copy taken? | When the batch is created: a `gambit_settings` jsonb column on `simulation_batches`, keyed by character id like `combatant_settings`, filled once (missing keys only). Every run of the batch is **simulated from that copy**, not from the database. | One copy per batch keeps every run of an experiment on the same rules, and running from the copy (not only logging it) means an edit mid-batch can't make the log lie. |
| "Repetir com ajustes" (rerun)? | Does not copy the gambits; the new batch snapshots the characters' current rules. | Gambits are not editable in the experiment builder, only on the character; repeating after editing them is the point. |
| Shape of the per-combatant section? | Per side, per combatant: `mode` ("gambits" or "aleatório") and every rule in priority order with position, on/off, target, condition, action and the full readable rule. All-disabled rules are listed with mode "aleatório". | The task asks for target, condition, action and on/off per rule; the mode makes the random fallback explicit. |
| Which turn entries carry the fired gambit? | Every decision entry: `{ position, rule }`, `"nenhum aplicável: parado"` or `"aleatório"`. A War Magic bonus inherits the gambit of the spell turn that triggered it; turn-start/turn-end passives carry none. | Passives and the bonus are not decisions; inheriting keeps the bonus traceable to its rule. |
| Where does the section sit in each simulation file? | Right after `simulation`, `seed` and `elapsed_ms`, before `round_log`. | "No começo" of the file while keeping the run's identity first. |

**Pass 3 status (2026-10-09):** review blocked once on a test gap (an empty `[]` copy
could be rewritten by a later save via `.presence`); the orchestrator added that assertion
and a renamed-feature check to the zip-immutability test, both proven red by sabotage, and
reordered the section's keys in each simulation file (jsonb scrambles them). Known,
non-blocking: the combatant's `name` in the section comes from the database (null if the
character is deleted), like the pre-existing `party_one`/`party_two` maps.

# Pass 4 — UI

| Question | Decision | Why |
|---|---|---|
| Where does the screen live? | Its own page, `/player_characters/:id/gambits` (nested `resources :gambits`), linked by a "Gambits" button on the character sheet, which also lists the enabled rules read-only. | The sheet is already long; FFXII keeps gambits on their own menu screen. |
| Save model? | Each slot saves on its own (one form per filled slot, PATCH); an empty slot is a "new rule" form (POST, next position). Toggle, up/down and delete are small `button_to` forms, so everything works without JS. | Matches the per-row FFXII editing; no client-side state to lose. |
| Drag and drop? | Native HTML5 DnD in a Stimulus controller (`gambits_controller.js`), which on drop sends the new id order to `PATCH .../gambits/reorder`; the server rewrites every position in one transaction (unique constraint deferred). Up/down buttons are the keyboard path. SortableJS not added. | The task asks to try native first; the list is ≤ 6 rows, native DnD is enough. |
| Which actions are offered? | The character's own turn actions (the pass-2 inventory filtered to it): Ataque, unlocked Second Wind/Action Surge, known maneuvers with an effect, known spells with an effect. A rule pointing elsewhere (e.g. after a preset) still shows its action, marked "indisponível". | Offering everything would make rules that can never fire; keeping foreign rules visible avoids silent data loss. |
| Invalid combinations (target/condition vs action)? | Server-side validation; the slot re-renders with the error. Stimulus only hides the value input when the condition takes none. | The model already validates; duplicating rules in JS is drift risk. |

Smaller choices taken while building pass 4:

| Question | Decision | Why |
|---|---|---|
| How does the switch work without JS? | A `button_to` with `role="switch"`/`aria-checked`, reading "● Ligado" / "○ Desligado". | A checkbox would need JS to submit; a button inside a form works everywhere. |
| A hidden value field with a stale number? | Stimulus also disables it, and `GambitsController#gambit_params` clears `condition_value` whenever the submitted condition is not in `Gambit::CONDITIONS_WITH_VALUE`. | Without the clearing, switching "HP abaixo de 40" to "Qualquer" never saved (the stored 40 failed the absence validation); review iteration 2. |
| Concurrent writes to positions? | `create`, `move`, `destroy` (with its renumbering) and `reorder` run in one transaction holding `lock!` on the character; every position is rewritten. Not covered by a real concurrency test. | Two requests reading the same positions could otherwise write duplicates or gaps. |
| Malformed input to `move`/`reorder`? | `direction` other than up/down and `ids` that are not a list of strings answer 422. | A tampered request must not 500 nor be read as "down". |
| Order of the action options? | Ataque, then features by unlock level and name, then spells by level and name (`PlayerCharacter#gambit_action_options`, values from `Gambit#action_choice`). | Deterministic select order; pass 5 reuses both. |
| Where does a refused 7th gambit show its error? | An alert above the list (the new-rule form is not rendered with 6 rules). | There is no empty slot to attach it to. |
| A drop the server refuses (stale page)? | The page reloads anyway and shows the stored order. | The server is the truth; no client-side rollback. |
| All rules off, on the sheet? | The summary lists them dimmed plus "Todos desligados: ação aleatória." | Otherwise the sheet would suggest the rules still drive the turn. |

**Pass 4 status (2026-10-09):** done. Review iteration 1 blocked (switching to a condition without a value never saved; tampered reorder ids gave a 500; three test gaps), iteration 2 came back non-blocking. The orchestrator then made `reorder` accept only digit strings (`"12abc"` used to pass as 12). Known and accepted: the server accepts, via a tampered request, an action outside the character's options — consistent with "(indisponível)" rules and presets, and the simulator skips it; the row lock in create/move/destroy/reorder has no concurrency test.

# Pass 5 — presets

| Question | Decision | Why |
|---|---|---|
| Model? | `gambit_presets` (`name` unique, case-insensitive, stripped), `has_many :gambits, as: :owner, dependent: :destroy`, reusing the `gambits` table, validations and labels. | Task decision: same table, same validations. |
| Where is the preset UI? | A "Presets" panel on the character's gambits screen: "Salvar como preset" (new name, or overwrite a chosen one) and "Aplicar preset" (select + confirm). No preset index or editor screen. | "Editar um preset fora de um personagem" is out of scope; everything starts from a character. |
| Copy semantics? | Save and apply both delete the destination's rules and insert copies (position, enabled, target, condition, value, action), in one transaction; no link is kept. | Task decision: copy both ways. |
| Saving a character with no rules? | Refused ("sem regras para salvar"). | An empty preset would wipe characters it is applied to. |
| Applying a preset with an action the character lacks? | Copied anyway; the screen shows it "(indisponível)" and the simulator skips it. | Same rule as pass 1; presets are meant to travel between characters. |
| Overwrite confirmation? | `turbo_confirm` on overwrite and apply ("substitui as N regras atuais"). | Both are destructive for the destination. |

Smaller choices taken while building pass 5:

| Question | Decision | Why |
|---|---|---|
| Where do the preset actions live? | Collection routes on the character's gambits (`save_preset`, `overwrite_preset`, `apply_preset`) in `GambitsController`, reusing its character scoping and screen loading; no `GambitPresetsController`. | A refusal re-renders the gambits screen (422) with the error in the panel; a second controller would duplicate `load_screen`. |
| Positions of the copies? | Renumbered 1..n in the source's priority order, not copied verbatim. | Same result for compact sources; a source with gaps still yields a valid compact list. It also makes the order of the copy observable (and testable). |
| Overwriting from a character with no rules? | Refused like saving ("sem regras para salvar"); the preset keeps its rules. | Same reason as saving: an empty preset would wipe characters. |
| Missing or malformed `preset_id`? | Unknown id → 404; absent or non-scalar → 400 (`params.expect`). Never 500. | Same style as the rest of the controller. |
| Two concurrent saves with the same name? | The unique index on `lower(name)` refuses the second (a 500 in that race, not rescued). | Single-user tool; the validation covers every non-concurrent case. |

**Pass 5 status (2026-10-09):** done. Review blocked once: the controller's refusal to overwrite a preset from a character without rules (and to apply an empty preset) had no test, and two tabs saving the same name raised `RecordNotUnique` (500). The orchestrator added both tests, rescued the race into the same 422 as a duplicate name, tested the non-string name guard, and hid "Sobrescrever" for a character without rules; each proven red by sabotage.
