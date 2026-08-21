---
type: Component
title: Phlex UI components
description: The Phlex-based view-component layer (Components::Base hierarchy, RubyUI widgets) used in place of most ERB templates.
resource: app/components
tags: [ui, phlex]
generated:
  by: copilot-cli/claude-sonnet-5
  at: 2026-08-21T23:39:26Z
sources:
  - id: components-base-rb
    title: app/components/base.rb
    resource: ../../app/components/base.rb
status: stable
---

# Overview

Phlex components combine Ruby logic and HTML markup as reusable objects.
They live in `app/components/` and inherit from `Components::Base`, which
includes `RubyUI`, `Phlex::Rails::Helpers` (route helpers, `form_with`,
`link_to`, `button_to`, `dom_id`, `turbo_frame_tag`,
`pluralize`).[^components-base-rb]
`Components::Layout` (header + sidebar) and
`Components::PlayerClassComponents` (forms/show for `PlayerClass`) are the
main composed components; `RubyUI::*` supplies lower-level widgets (`Button`,
`Form`, `Link`, `Table`, `Typography`, `Card`, `Badge`) under
`app/components/ruby_ui/`.[^components-base-rb]

Not every view has been migrated: some views (e.g.
`app/views/player_characters/show.html.erb`) remain traditional ERB and
render fine alongside Phlex components — the two coexist by design, not as
an in-progress migration to complete.

Components are tested by instantiating and calling `render_to_string`,
asserting on the returned HTML — see `test/components/`.
