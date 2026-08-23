---
type: Component
title: ERB + Bootstrap views
description: The ERB view layer styled with Bootstrap 5 (via dartsass-rails), which replaced the previous Phlex/RubyUI component layer.
resource: app/views
tags: [ui, bootstrap]
generated:
  by: copilot-cli/claude-sonnet-5
  at: 2026-08-23T00:00:00Z
sources:
  - id: application-layout
    title: app/views/layouts/application.html.erb
    resource: ../../app/views/layouts/application.html.erb
  - id: application-scss
    title: app/assets/stylesheets/application.scss
    resource: ../../app/assets/stylesheets/application.scss
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
`btn btn-primary`, `table table-striped`, `alert alert-danger`).

`app/views/layouts/application.html.erb` is the single shared layout: a
sidebar `<nav>` plus a `<main>` content area, both styled with Bootstrap flex
utilities (`d-flex`, `flex-column`, `container-fluid`).[^application-layout]
JavaScript (Bootstrap's own JS plus Popper) is pinned in
`config/importmap.rb` and loaded via `javascript_importmap_tags`; there is no
Stimulus controller registry in the app.

Views are tested via system tests (Capybara) exercising the rendered pages —
see `test/system/`.
