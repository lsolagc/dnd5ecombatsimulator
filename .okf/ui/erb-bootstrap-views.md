---
type: Component
title: ERB + Bootstrap views
description: The ERB view layer styled with Bootstrap 5 (via dartsass-rails), which replaced the previous Phlex/RubyUI component layer.
resource: app/views
tags: [ui, bootstrap]
generated:
  by: copilot-cli/claude-sonnet-5
  at: 2026-08-23T23:30:00Z
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
disabled "Simulações" placeholder for the not-yet-built feature) plus a
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
previously an installed-but-unused gem). Three controllers exist:
`theme_controller.js` (above), `class_row_controller.js` (toggles the
expandable progression/features row on `player_classes#index`), and the
larger `wizard_controller.js` driving the character-creation wizard below.
None of them make network requests — all client-side state and DOM
toggling, with the actual persistence happening on normal Rails form
submits.

# The three screens

- **`home#index`**: a hero explaining the simulator, a 3-step "how it works"
  strip, and three shortcut cards (Personagens/Classes counts pulled from
  `PlayerCharacter.count`/`PlayerClass.count`; a disabled "Simulações" card
  since that feature doesn't exist yet).
- **`player_classes#index`**: a filterable table (`q` name search, `hit_die`
  and `spellcasting_modifier` selects — plain GET params, no Turbo Frame)
  where each row expands in place (via `class_row_controller.js`) into that
  class's `class_level_progressions` table and a chip list of its
  `class_features`, styled by `action_type` and whether any
  `class_feature_unlock` on the feature carries an `effect_payload`.
- **`player_characters#new`**: a 4-step wizard (Atributos / Combate /
  Features / Revisão) navigated client-side by `wizard_controller.js`[^wizard-controller] — no
  server round-trip between steps, one form submitted on the last step.
  Ability score steppers, armor class, and speed write to
  `player_character[combatant_attributes][...]`, which
  [PlayerCharacter](/models/player-character.md) now accepts via
  `accepts_nested_attributes_for :combatant`.[^player-characters-controller]
  Resistances/immunities/vulnerabilities are edited as R/I/V-cycling chips
  backed by a single `player_character[damage_type_flags][<type>]` value per
  damage type; `PlayerCharactersController` translates that flag hash into
  the three separate `Combatant` jsonb columns before
  save.[^player-characters-controller] The Features step is read-only
  (derived from the selected class's `class_features`/
  `class_feature_unlocks`); the Combate step's weapon fields (main/offhand)
  are rendered to match the design but **are not backed by any model** —
  there is no `Weapon` concept in the schema yet, so those inputs have no
  `name` attribute and are dropped on submit.

Views are tested via system tests (Capybara) exercising the rendered pages —
see `test/system/`.
