---
type: Runbook
title: Local development setup
description: Install, database setup, running the dev server, and running the test suite for the Rails app.
tags: [setup, dev, runbook]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-06T02:15:00Z
sources:
  - id: gemfile
    title: Gemfile / .ruby-version
    resource: ../../Gemfile
  - id: agents-md
    title: AGENTS.md
    resource: ../../AGENTS.md
status: stable
---

# Overview

Prerequisites: Ruby 3.x (`.ruby-version` pins 3.4.2), Rails 8.x, Node.js 18+,
Yarn or npm, PostgreSQL (development uses three databases: the app's,
`dnd_development_queue` for Solid Queue and `dnd_development_cable` for Solid
Cable; credentials from `DB_USER`/`DB_PASS`), Git.[^gemfile]

This is the environment used to run and test the system described in
[architecture/overview.md](/architecture/overview.md).

# Steps

```bash
bundle install && yarn install
bin/rails db:prepare db:seed  # creates/loads all three databases; seed data: YAML under db/seeds/ (templates in db/seeds/templates/)
./bin/dev                    # Rails server on :3000 + Bootstrap Sass watch (dartsass) + job workers (bin/jobs)
```

# Testing and linting

```bash
bin/rails test               # full suite
bin/rails test test/models
bin/rails test test/services
bin/rails test test/integration

bundle exec rubocop          # lint — Rubocop Omakase style, see .rubocop.yml
```

# Migrations

Always generate migrations with the Rails generator and edit the generated
file — never hand-write a migration timestamp.[^agents-md]

# Common issues

- **Gem not found** → `bundle install --local` or `bundle install`.
- **Database doesn't exist** → `rails db:create db:migrate`.
- **Assets not loading** → `./bin/importmap pin` then `rails
  assets:precompile`.
- **Port 3000 in use** → `rails server -p 3001`.
- **Experiment stuck "Na fila"** → no job worker is running: start the app
  with `./bin/dev` (or run `bin/jobs` beside `rails server`). See
  [architecture/simulation-batches.md](/architecture/simulation-batches.md).
- **Changed `config/` (queue, cable, database)** → restart `./bin/dev`;
  config is not reloaded by a running server.
