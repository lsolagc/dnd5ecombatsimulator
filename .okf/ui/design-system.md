---
type: Design System
title: Design system — D20 · SIM
description: Where the UI design system lives (docs/design-system/), what each part is for, how it maps onto the Bootstrap code, and the few cross-cutting rules behind the screens' look and copy.
resource: docs/design-system
tags: [ui]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-11T00:00:00Z
verified: { by: human:lsolagc, at: 2026-10-11T22:04:15Z }
sources:
  - id: ds-readme
    title: docs/design-system/README.md
    resource: https://github.com/lsolagc/dnd5ecombatsimulator/blob/main/docs/design-system/README.md
  - id: ds-tokens
    title: docs/design-system/tokens.json
    resource: ../../docs/design-system/tokens.json
  - id: application-scss
    title: app/assets/stylesheets/application.scss
    resource: ../../app/assets/stylesheets/application.scss
---

# Overview

The design system says how the UI should look and read; the
[ERB + Bootstrap views](/ui/erb-bootstrap-views.md) page says how the views
are built. Its source of truth is `docs/design-system/`, written in pt-BR.
This page points into it and does not restate its rules, so the two cannot
drift apart.

| Part | What it holds |
|---|---|
| `README.md` | The rules: content and voice, color, typography, space and layout, components, accessibility, iconography.[^ds-readme] |
| `tokens.json` | Every token (color for the light and dark themes, type, space, radii) with its value and usage.[^ds-tokens] |
| `components/<Name>/` | One folder per component (Navbar, PageHeader, CombatantCard, GambitSlot, WinBar, RunProgress, …): a `README.md` with its rules and a `preview.html`. |
| `components/bundle.css` | The CSS the previews share, rebuilt from the tokens. |

# How it maps onto the code

- **Bootstrap 5.3 is the base.** The brand terracotta `#b3563c` is
  `$primary` in `application.scss`, set before `@import "bootstrap"`;
  everything else is Bootstrap's neutral scale.[^application-scss] The
  previews recreate Bootstrap's and `application.scss`'s classes from the
  tokens; in the app, Bootstrap provides them.
- **Light and dark themes** use Bootstrap's `data-bs-theme`, with the
  Claro / Escuro / Sistema selector in the navbar. Every token has a value in
  both themes.[^ds-tokens]
- **Interactions** use Stimulus, progress uses Turbo Streams, and charts are
  plain HTML and CSS (the win bar is `div`s). No React, no icon or chart
  library.[^ds-readme]

# Rules that shape decisions

The README has the full list. These are the ones that explain choices made
across screens:[^ds-readme]

- **One primary action per screen.** `primary` marks only that action, the
  active wizard step, the progress bar and an edited field's border.
- **Side colors are never text.** `side-a` (blue) and `side-b` (orange) mark
  borders, dots and bars, always next to the letter "A"/"B" or a label.
- **Color never carries meaning alone:** a side has its letter, "Ligado" has
  the word, an edited field has "•" in its label.
- **No shadows:** separation is a 1 px border.
- **Copy:** pt-BR, short, imperative, no exclamation marks or emoji; game
  terms stay as in D&D (feature and maneuver names in English); numbers in
  Brazilian format ("58,0%"). A gambit is written "Alvo: condição → ação";
  the word for a gambit's test is changing to "critério"
  ([ubiquitous language](/ubiquitous-language.md)).

[^ds-readme]: Source: `docs/design-system/README.md`

[^ds-tokens]: Source: `docs/design-system/tokens.json`

[^application-scss]: Source: `app/assets/stylesheets/application.scss`
