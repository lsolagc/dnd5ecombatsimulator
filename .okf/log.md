# Update Log

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
