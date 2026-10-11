# Update Log

## 2026-10-09
* **Update**: The experiment screens (`/simulation_batches/new` and `/:id`) follow the design system in `docs/design-system/`: combatant cards show a gambits summary with an "Editar gambits" link, the roster shows each combatant's gambits from the batch's copy, and the navbar no longer overflows at 390 px — [architecture/simulation-batches.md](architecture/simulation-batches.md), [ui/erb-bootstrap-views.md](ui/erb-bootstrap-views.md).
* **Update**: `gambits:brenna_corwin` configures the two dev-only Fighters ([ops/dev-setup.md](ops/dev-setup.md)); a real 50-run batch shows both rule sets in its log. Mechanics impact recorded in [architecture/gambits-impact.md](architecture/gambits-impact.md).
* **Update**: Gambit presets (`gambit_presets`, a second owner of `gambits`): save a character's rules as a new preset or overwrite one, and apply a preset to another character — copies both ways, no live link (`Gambit.copy_rules`) — [models/gambit.md](models/gambit.md).
* **Update**: Characters have a gambits screen (`/player_characters/:id/gambits`): 6 slots, native drag and drop plus ↑/↓, on/off, per-slot editing; the sheet shows a summary — [ui/erb-bootstrap-views.md](ui/erb-bootstrap-views.md), decisions in [architecture/gambits-decisions.md](architecture/gambits-decisions.md).
* **Update**: Batches copy each character's gambits at creation (`simulation_batches.gambit_settings`) and simulate from that copy; the log zip opens every file with a per-side gambits section and each decision turn records the gambit that fired, "nenhum aplicável: parado" or "aleatório" — [architecture/simulation-batches.md](architecture/simulation-batches.md), [architecture/combat-simulator-service.md](architecture/combat-simulator-service.md).
* **Update**: Gambits cover every turn action the Fighter has (attack, Second Wind, Action Surge, 5 maneuvers, 5 spells) and gained hp_above, highest_hp, marked/unmarked and resource_at_least. Action Surge is a gambit action that re-evaluates the list twice; gambit-driven actors no longer surge automatically and their War Magic bonus is deterministic — [architecture/combat-simulator-service.md](architecture/combat-simulator-service.md), [models/gambit.md](models/gambit.md), inventory in [architecture/gambits-decisions.md](architecture/gambits-decisions.md).

## 2026-10-08
* **Creation**: [models/gambit.md](models/gambit.md) — FFXII-style turn rules (target + condition + action, up to 6 per owner, polymorphic owner, deferrable unique position) and [architecture/gambits-decisions.md](architecture/gambits-decisions.md), the decisions taken autonomously while building them. [architecture/combat-simulator-service.md](architecture/combat-simulator-service.md) now documents gambit-driven turns: rules by priority, targets in initiative order, idle turns, no `@rng` draws; actors without enabled gambits keep the random choice.

## 2026-10-06
* **Update**: Experiments now run one `SimulationRunJob` per simulation on Solid Queue worker processes (`bin/jobs`, in `bin/dev`; Puma plugin in production) and push progress over Solid Cable as a morphing Turbo Stream, throttled to 0.2 s, instead of in-process jobs with 1 s polling. Simulator and `PlayerCharacter` lookups are cached per simulation (590 → 97 ms per simulation, results byte-identical). Fixed along the way: cancellation never reached running simulations in workers (query cache), and a combat cancelled in its last round was still saved. Updated [architecture/simulation-batches.md](architecture/simulation-batches.md), [architecture/combat-simulator-service.md](architecture/combat-simulator-service.md), [models/player-character.md](models/player-character.md) and [ops/dev-setup.md](ops/dev-setup.md) (which also wrongly said development used SQLite).
* **Fix**: [ui/erb-bootstrap-views.md](ui/erb-bootstrap-views.md) said the wizard's weapon fields were not persisted; the main weapon's attack bonus, damage dice and damage type are `Combatant` columns, only the weapon name and the offhand weapon are visual-only.
* **Update**: [architecture/simulation-batches.md](architecture/simulation-batches.md) — characters are now blueprints for experiments: a batch stores per-combatant `combatant_settings` (starting HP, AC, attack bonus, weapon damage dice and type, R/I/V defenses), snapshotted from the sheet and applied in memory only, so the sheet never changes. The builder and result pages were redesigned (per-side panels with editable cards, edit markers, "Repetir com ajustes", headline + win-rate bar + metric tiles), and the damage-type labels moved to `ApplicationHelper::DAMAGE_TYPE_LABELS`, shared with the character wizard and sheet.

## 2026-10-05
* **Update**: [architecture/simulation-batches.md](architecture/simulation-batches.md) gained a Verification section: what the batch system test covers end to end, and that the in-flight abort is covered only at the job/service level.
* **Fix**: `PlayerCharacter#get_attacked` no longer raises when a hit rolls 0 damage (e.g. 1d4 with a -1 STR modifier rolling a 1): `take_damage` only runs on positive damage, as `EffectExecutor` already did. Random batch seeds made this crash any batch with a low-STR character. Updated [models/player-character.md](models/player-character.md).
* **Create**: [architecture/simulation-batches.md](architecture/simulation-batches.md) — `SimulationBatch`/`SimulationRun`, `SimulationBatchJob` and the `simulation_batches` screens: two sides of several characters, up to 1000 combats (a seed forces exactly one), progress polling, cancellation that aborts the in-flight combat, a summary (win rate, healing done/wasted, biggest damage in a round) and a zipped JSON log with each run's seed. `CombatSimulatorService` gained `abort_if:` and weapon attack entries now carry `hp_before`/`hp_after`. Updated [architecture/combat-simulator-service.md](architecture/combat-simulator-service.md) and [ui/erb-bootstrap-views.md](ui/erb-bootstrap-views.md).

## 2026-09-20
* **Update**: Battle Master maneuvers are no longer standalone 1d8 actions. A payload with `"applies_to": "weapon_attack"` turns the turn into a normal weapon attack and, only on a hit, adds the maneuver die as extra damage (doubled on a critical hit) and spends a superiority die; a miss spends nothing. Distracting Strike also declares `"debuff": "next_attack_advantage"`: the target is marked, the next weapon attack against it by anyone but the marker has advantage, and the mark expires at the start of the marker's next turn. Simplifications: the die is its own damage instance rather than part of the weapon's roll, Precision Attack still adds damage instead of an attack-roll bonus, and spell attacks ignore marks. Documented in [architecture/combat-simulator-service.md](architecture/combat-simulator-service.md), [architecture/combat-effect-pipeline.md](architecture/combat-effect-pipeline.md) and [models/class-feature-unlock.md](models/class-feature-unlock.md).
* **Update**: An `effect_payload`'s `"target"` is now an explicit valid-target indicator — `self`, `enemy` (opposing party) or `ally` (own party, actor included) — replacing the old `target`, which let `CombatSimulatorService` pick any living combatant, so a damage maneuver or spell could hit its own user and a heal could reach an enemy. The simulator draws only from the valid candidates, raises on an unknown kind, and skips Action Surge's extra action once the fight is over (no target left). Seeds and fixtures moved from `target: target` to `target: enemy`. Documented in [architecture/combat-effect-pipeline.md](architecture/combat-effect-pipeline.md) and [architecture/combat-simulator-service.md](architecture/combat-simulator-service.md).
* **Update**: `db/seeds.rb` is now a one-liner (`SeedData.load_all`); the data moved to YAML under `db/seeds/`:
  `classes/<class>.yml` (class + level progression + features/unlocks, with subclasses nested as `subclass_features` and
  spell slots under `spell_slots`), `spells.yml` and `characters/*.yml` (a `PlayerCharacter` with its combatant stats,
  fighting style, archetype, spells and maneuvers, referenced by slug). Documented templates live in `db/seeds/templates/`.
  The loader (`lib/seed_data.rb`) keeps the old idempotency rules; the seeded catalog is byte-for-byte equivalent to the
  previous Ruby seed, and `db:seed` now also creates three example Fighter characters (Champion, Battle Master, Eldritch
  Knight). Updated [models/class-level-progression.md](models/class-level-progression.md) and
  [architecture/passive-effect-triggers.md](architecture/passive-effect-triggers.md).
* **Update**: Attack rolls now follow the 5e natural-20/natural-1 rule for both spells and weapons through one shared
  `Dice.hit?`: a natural 20 always hits (and is the critical hit that doubles the dice), a natural 1 always misses. Weapon
  attacks previously only compared total to AC; `PlayerCharacter#get_attacked` (also used by the frozen EncounterService)
  now applies the rule, `Dice::AttackRoll` exposes `natural`, and the `CombatSimulatorService` weapon-attack log carries it.
  Updated [architecture/combat-effect-pipeline.md](architecture/combat-effect-pipeline.md), [architecture/encounter-service.md](architecture/encounter-service.md),
  [architecture/combat-simulator-service.md](architecture/combat-simulator-service.md), [models/player-character.md](models/player-character.md)
  and [models/spell.md](models/spell.md).
* **Update**: Spells now use the caster's spellcasting ability. `PlayerCharacter#spell_save_dc` (8 + proficiency + ability
  modifier) and `#spell_attack_bonus` feed the combat pipeline: a damage payload with `"attack": "spell"` rolls a spell attack
  vs AC (miss = no damage, natural 20 doubles the dice via `RollExpression#resolve(crit:)`), and a save with `"dc": "spell"`
  uses the caster's DC. Seeds: Fire Bolt, Ray of Frost, Chromatic Orb, Scorching Ray are spell attacks; Fireball is a DEX save
  for half. `EffectExecutor::Result` gained `attack_roll`, also emitted in `CombatSimulatorService` round logs. Corrected the
  stale "spell-save DC not implemented" (class-level-progression.md) and "simulator does not cast" (spell.md) claims. Updated
  [architecture/combat-effect-pipeline.md](architecture/combat-effect-pipeline.md), [models/spell.md](models/spell.md),
  [models/player-character.md](models/player-character.md) and [models/class-level-progression.md](models/class-level-progression.md).
* **Update**: A spellcasting subclass can now declare its own spellcasting ability. New
  `class_features.spellcasting_ability` enum (`intelligence`/`wisdom`/`charisma`), required on a
  `grants_spellcasting` feature unless its class already has one; the Eldritch Knight's Spellcasting
  seeds `intelligence`. `PlayerCharacter#spellcasting_ability` resolves feature-then-class. Updated
  [models/class-feature.md](models/class-feature.md), [models/player-class.md](models/player-class.md)
  and [models/player-character.md](models/player-character.md).
* **Update**: Fixed three Fighter gaps. `PlayerCharacter#setup_hit_points` now gives full HP for the
  level (max hit die + CON modifier every level; `roll_hit_points` removed, it computed
  `for_level - level` = 0 extra levels) and the wizard preview mirrors it; seeded Battle Master
  maneuvers now all use `resource_name` "Superiority Dice" so `PlayerCharacterManeuver` accepts any
  of the 16; migration `BackfillFighterAttacksPerAction` corrects existing Fighter progression rows
  (1/2/3/4 attacks at levels 1-4/5-10/11-19/20). Updated [models/player-character.md](models/player-character.md),
  [models/player-class.md](models/player-class.md), [models/class-level-progression.md](models/class-level-progression.md)
  and [ui/erb-bootstrap-views.md](ui/erb-bootstrap-views.md).

## 2026-08-30
* **Update**: Made the basic weapon attack configurable per character instead of hardcoded. Added
  `attack_bonus` (integer, default 0), `damage_dice` (string, default `"1d4"`), and `damage_type`
  (string, default `"bludgeoning"`, validated against the existing damage-type set) columns on
  `combatants`; `PlayerCharacter#roll_an_attack`/`#damage_roll`/`#get_attacked` now read these
  instead of the previous fixed `d20+0`/`"1d4"`/`:bludgeoning` values. `EncounterService` and
  `CombatSimulatorService` needed no changes — both already call the same
  `roll_an_attack`/`get_attacked` pair, so the new fields (and multiattack) flow through
  automatically. The wizard's "Arma principal" box gained a real attack-bonus input and turned its
  dado-de-dano/tipo-de-dano inputs from decorative to real (`form.fields_for :combatant`), with the
  damage-type `<select>` listing the full damage-type set (matching the resistance chips); weapon
  name and the offhand weapon box remain visual-only, unchanged. Updated
  [models/combatant.md](models/combatant.md), [models/player-character.md](models/player-character.md),
  and [architecture/encounter-service.md](architecture/encounter-service.md) to describe the
  configurable fields instead of the old hardcoded values.

## 2026-08-24
* **Update**: Styled `player_characters#index`/`#show` and the `player_classes#new`/`#edit` creation
  form to match the Bootstrap design system established by the previous pass — replacing the
  scaffold-generated English markup with the same Portuguese, card/table/chip vocabulary used by
  `home` and `player_classes#index`. The character show page is a read-only sheet reusing the
  wizard's stat-tile and R/I/V-chip styling; the class form swaps `hit_die`/`spellcasting_modifier`
  from raw text fields to `form.select`s. `player_classes#show` and `player_characters#edit` were
  left as-is (out of scope for this pass). Rewrote [ui/erb-bootstrap-views.md](ui/erb-bootstrap-views.md)
  to describe every screen now, not just the original three.

## 2026-08-23
* **Update**: Implemented the three screens from the D&D 5e design handoff (home, player_classes#index,
  player_characters#new) and wired up Stimulus for the first time. Rewrote
  [ui/erb-bootstrap-views.md](ui/erb-bootstrap-views.md) — the shared layout moved from a bare sidebar to a
  horizontal navbar with a Claro/Escuro/Sistema theme toggle (Bootstrap's native `data-bs-theme` dark mode),
  Stimulus is no longer just an installed-but-unused gem (`theme_controller.js`, `class_row_controller.js`,
  `wizard_controller.js` now exist), and the three screens are described concretely (filterable expandable
  class table, 4-step character-creation wizard). Updated [models/player-character.md](models/player-character.md)
  for the new `accepts_nested_attributes_for :combatant`, which the wizard uses to write ability
  scores/armor_class/speed in one form submit. Noted that the wizard's weapon fields are visual only — there is
  still no `Weapon` model in the schema.

## 2026-08-23
* **Update**: The Phlex/RubyUI view-component layer (`app/components/`, `app/views/base.rb`) was removed;
  every view is now plain ERB styled with Bootstrap 5 (via `dartsass-rails`). Renamed and rewrote
  [ui/phlex-components.md](ui/phlex-components.md) → [ui/erb-bootstrap-views.md](ui/erb-bootstrap-views.md)
  to describe the ERB + Bootstrap layer instead of the removed Phlex components, and updated the inbound
  reference in [architecture/overview.md](architecture/overview.md), the [ui/index.md](ui/index.md) listing,
  and the top-level [index.md](index.md) rollup. Corrected the Tailwind-watch mention in
  [ops/dev-setup.md](ops/dev-setup.md) to the current `dartsass:watch` process.

## 2026-08-21
* **Creation**: Initial OKF bundle produced from the codebase and existing `docs/` architecture, covering combat architecture, persisted models, the UI component layer, and local dev setup — [architecture/overview.md](architecture/overview.md), [architecture/encounter-service.md](architecture/encounter-service.md), [architecture/combat-effect-pipeline.md](architecture/combat-effect-pipeline.md), [architecture/combat-migration-strategy.md](architecture/combat-migration-strategy.md), [models/player-character.md](models/player-character.md), [models/player-class.md](models/player-class.md), [models/class-level-progression.md](models/class-level-progression.md), [models/combatant.md](models/combatant.md), [models/class-feature.md](models/class-feature.md), [models/class-feature-unlock.md](models/class-feature-unlock.md), [ui/phlex-components.md](ui/phlex-components.md), [ops/dev-setup.md](ops/dev-setup.md).
* **Update**: Corrected [models/player-character.md](models/player-character.md), [models/combatant.md](models/combatant.md), and [models/player-class.md](models/player-class.md) — the initial pass had inherited stale claims from `docs/` (ability scores/HP/armor class were described as living on `PlayerCharacter`; they actually live on `Combatant`, which uses `delegated_type`, not a raw polymorphic association; `PlayerClass` has no `has_many :player_characters`; `spellcasting_modifier` has no `none` enum value; there is no `LevelUpService` — it was removed).
* **Update**: Corrected [architecture/encounter-service.md](architecture/encounter-service.md) to the actual current contract (`party_one:`/`party_two:` keyword args, `call` returns `self`, results read via `encounter_log`, hardcoded `:bludgeoning` damage type) — the legacy `docs/architecture/combat-system.md` it was sourced from had already drifted from the code.
* **Update**: [architecture/overview.md](architecture/overview.md) and [architecture/combat-migration-strategy.md](architecture/combat-migration-strategy.md) now account for the new `CombatSimulatorService` and passive-trigger mechanism alongside `EncounterService` and the `Combat::*` pipeline.
* **Creation**: [architecture/combat-simulator-service.md](architecture/combat-simulator-service.md) — a new, seeded combat orchestrator combining basic attacks with class-feature effects, distinct from `EncounterService`.
* **Creation**: [architecture/passive-effect-triggers.md](architecture/passive-effect-triggers.md) — documents the `always`/`turn_start`/`turn_end` `effect_payload` mechanism (e.g. Champion's improved critical), which the maintain pass found undocumented in both the prior bundle and `docs/`.
* **Update**: The pre-existing `docs/` directory was deleted from the repo (no longer needed now that `.okf/` is the maintained knowledge bundle). Re-pointed every `sources[]` citation that referenced a `docs/*.md` file to the equivalent code file instead, dropped citations for claims that had no code-verifiable equivalent (kept as uncited prose or corrected — e.g. the previously-cited spell-save-DC formula in [models/class-level-progression.md](models/class-level-progression.md) was not found anywhere in the codebase and is now flagged as **not yet implemented** rather than a verified behavior), and updated `README.md`/`AGENTS.md` entry-point links from `docs/*` to `.okf/*`. Affected concepts: [architecture/combat-effect-pipeline.md](architecture/combat-effect-pipeline.md), [architecture/combat-migration-strategy.md](architecture/combat-migration-strategy.md), [architecture/encounter-service.md](architecture/encounter-service.md), [architecture/overview.md](architecture/overview.md), [models/class-feature.md](models/class-feature.md), [models/class-feature-unlock.md](models/class-feature-unlock.md), [models/class-level-progression.md](models/class-level-progression.md), [models/combatant.md](models/combatant.md), [models/player-character.md](models/player-character.md), [models/player-class.md](models/player-class.md), [ops/dev-setup.md](ops/dev-setup.md), [ui/phlex-components.md](ui/phlex-components.md).
