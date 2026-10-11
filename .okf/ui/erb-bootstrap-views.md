---
type: Component
title: ERB + Bootstrap views
description: The ERB view layer styled with Bootstrap 5 (via dartsass-rails), which replaced the previous Phlex/RubyUI component layer.
resource: app/views
tags: [ui]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-11T00:00:00Z
sources:
  - id: application-layout
    title: app/views/layouts/application.html.erb
    resource: ../../app/views/layouts/application.html.erb
  - id: application-scss
    title: app/assets/stylesheets/application.scss
    resource: ../../app/assets/stylesheets/application.scss
  - id: wizard-controller
    title: app/javascript/controllers/wizard_controller.js
    resource: ../../app/javascript/controllers/wizard_controller.js
  - id: player-characters-controller
    title: app/controllers/player_characters_controller.rb
    resource: ../../app/controllers/player_characters_controller.rb
status: stable
---

# Overview

All views are plain Rails ERB templates under `app/views/`, styled with
Bootstrap 5 (the `bootstrap` gem's Sass sources, compiled by
`dartsass-rails`) instead of Tailwind.[^application-scss] There is no
separate view-component layer: `app/components/` and `Views::Base` (the
former Phlex/RubyUI layer) were removed, and every screen — `home`,
`player_classes`, `player_characters` — is a standard controller +
`.erb`/`.jbuilder` view pair, generated in the conventional Rails scaffold
style (`form_with`, `link_to`, `pluralize`, Bootstrap utility classes like
`btn btn-primary`, `table table-striped`, `alert alert-danger`). Screen copy
is written in Portuguese (pt-BR), matching the D&D 5e design handoff the
three screens below were built from; there is no i18n locale layer — strings
are hardcoded per view.

`app/views/layouts/application.html.erb` is the single shared layout: a
horizontal Bootstrap `navbar` (brand, Início/Personagens/Classes links, a
"Simulações", which opens the [simulation batch](/architecture/simulation-batches.md) form) plus a
`<main>` content area.[^application-layout] The navbar also hosts a
Claro/Escuro/Sistema theme segmented control, backed by Bootstrap 5's native
`data-bs-theme` dark mode: the layout reads the `theme` cookie server-side to
set the initial `data-bs-theme` on `<html>` (avoiding a flash for explicit
choices), and a Stimulus `theme` controller resolves "Sistema" via
`prefers-color-scheme` and persists the choice back to the cookie on the
client. `application.scss` sets Bootstrap's `$primary` to an approximation of
the design handoff's terracotta accent before `@import "bootstrap"`.[^application-scss]

**Stimulus is now wired up** (`stimulus-rails`'s standard
`app/javascript/controllers/` + importmap `pin_all_from` setup — it was
previously an installed-but-unused gem). Besides
`theme_controller.js` (above), `class_row_controller.js` (toggles the
expandable progression/features row on `player_classes#index`), and the
larger `wizard_controller.js` driving the character-creation wizard below,
`simulation_form_controller.js` and `poll_controller.js` serve the
[simulation batch](/architecture/simulation-batches.md) screens, and
`gambits_controller.js` the gambits screen. Only `poll_controller.js` and
`gambits_controller.js` make requests (the first reloads a turbo-frame, the second PATCHes `reorder` on drop); the others are all client-side state and DOM
toggling, with the actual persistence happening on normal Rails form
submits.

# The screens

- **`home#index`**: a hero explaining the simulator, a 3-step "how it works"
  strip, and three shortcut cards (Personagens/Classes counts pulled from
  `PlayerCharacter.count`/`PlayerClass.count`; a "Simulações" card with
  `SimulationBatch.count` linking to the batch form).
- **`player_classes#index`**: a filterable table (`q` name search, `hit_die`
  and `spellcasting_modifier` selects — plain GET params, no Turbo Frame)
  where each row expands in place (via `class_row_controller.js`) into that
  class's `class_level_progressions` table and a chip list of its
  `class_features`, styled by `action_type` and whether any
  `class_feature_unlock` on the feature carries an `effect_payload`.
- **`player_classes#new`/`#edit`**: a single Bootstrap form (`_form.html.erb`)
  with `hit_die` and `spellcasting_modifier` as `form.select`s sourced from
  `PlayerClass.hit_dice`/`PlayerClass.spellcasting_modifiers` (the latter with
  a "Nenhuma" blank option, since not every class casts spells) instead of the
  scaffold's raw text fields. `player_classes#show` was left as the
  English-language scaffold — it wasn't part of this design pass.
- **`player_characters#index`**: a table (Nome/Classe/Nível/HP/CA, eager-loading
  `:player_class` and `:combatant`) styled like `player_classes#index` but
  without row-expansion or filters — each row links to `#show` plus
  Editar/Excluir actions.
- **`player_characters#show`**: a read-only character sheet — stat tiles
  (HP máx./CA/Deslocamento/Bônus prof./Ataques), the six ability scores with
  their modifiers, R/I/V chips for any flagged damage type (reusing the
  `.wizard-chip`/`.wizard-chip--active` CSS from the wizard, read-only here),
  and the owning class's `class_features` as badges — the same feature-badge
  markup as `player_classes#index`'s expanded row and the wizard's Features
  step, duplicated a third time rather than extracted into a partial (no
  screen shares a controller with the others, so there's nowhere natural to
  put a shared partial yet).
- **`gambits#index`** (`/player_characters/:id/gambits`): the character's
  [gambits](/models/gambit.md) as 6 slots — each filled slot is its own form
  (target/condition/value/action, Salvar) plus `button_to` forms for on/off,
  ↑/↓ and Remover; the first empty slot is the "Novo gambit" form. The
  Stimulus `gambits_controller.js` does native HTML5 drag and drop (dropping
  a slot on another PATCHes the new id order to `reorder`, then reloads) and
  hides the value field for conditions that take none. The sheet
  (`player_characters#show`) links to it and lists the rules read-only.
  Below the slots, a **Presets** panel saves the rules as a new preset (unique
  name) or overwrites a chosen one, and applies a preset to this character
  (both with a Turbo confirm), copying rules without a live link.
  Decisions: [gambits-decisions.md](/architecture/gambits-decisions.md) (Pass 4, 5).
- **`player_characters#new`**: a 4-step wizard (Atributos / Combate /
  Features / Revisão) navigated client-side by `wizard_controller.js`[^wizard-controller] — no
  server round-trip between steps, one form submitted on the last step. The Revisão HP
  preview (`hpPreview`) mirrors `PlayerCharacter#full_hit_points` (`level × (hit die + CON
  modifier)`) and always shows a number, at any level, unless an HP override is typed.
  Ability score steppers, armor class, and speed write to
  `player_character[combatant_attributes][...]`, which
  [PlayerCharacter](/models/player-character.md) now accepts via
  `accepts_nested_attributes_for :combatant`.[^player-characters-controller]
  Resistances/immunities/vulnerabilities are edited as R/I/V-cycling chips
  backed by a single `player_character[damage_type_flags][<type>]` value per
  damage type; `PlayerCharactersController` translates that flag hash into
  the three separate `Combatant` jsonb columns before
  save.[^player-characters-controller] The damage-type labels (pt-BR) come
  from `ApplicationHelper::DAMAGE_TYPE_LABELS`, shared with the sheet and the
  [simulation experiment](/architecture/simulation-batches.md) cards. The
  Features step is read-only (derived from the selected class's
  `class_features`/`class_feature_unlocks`). In the Combate step the main
  weapon's attack bonus, damage dice and damage type are real `Combatant`
  columns (`attack_bonus`, `damage_dice`, `damage_type`); only the weapon
  *name* and the whole offhand weapon are visual-only — there is no `Weapon`
  concept in the schema yet, so those inputs have no `name` attribute and are
  dropped on submit.

Views are tested via system tests (Capybara) exercising the rendered pages —
see `test/system/`.

[^application-scss]: Source: `app/assets/stylesheets/application.scss`

[^application-layout]: Source: `app/views/layouts/application.html.erb`

[^wizard-controller]: Source: `app/javascript/controllers/wizard_controller.js`

[^player-characters-controller]: Source: `app/controllers/player_characters_controller.rb`
