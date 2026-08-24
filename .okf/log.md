# Update Log

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
