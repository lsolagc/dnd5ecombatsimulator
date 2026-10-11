---
type: Runbook
title: Local development setup
description: Install, database setup, running the dev server, and running the test suite for the Rails app.
tags: [setup]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-11T00:00:00Z
sources:
  - id: gemfile
    title: Gemfile / .ruby-version
    resource: ../../Gemfile
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
file — never hand-write a migration timestamp.

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

# Gambits for Brenna and Corwin

`bash -ic 'bin/rails gambits:brenna_corwin'` gives the dev-only characters Brenna
Ironhide and Corwin Vale their gambits (rules in `lib/gambit_setups.rb`, reasons in
[gambits-decisions.md](/architecture/gambits-decisions.md), Pass 6). Found by exact
name; replaces only their gambits, in one transaction, so running it again is a
no-op — and also undoes manual edits made to their rules since.

[^gemfile]: Source: `Gemfile / .ruby-version`
