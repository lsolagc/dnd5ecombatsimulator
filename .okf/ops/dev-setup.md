---
type: Runbook
title: Local development setup
description: Install, database setup, running the dev server, and running the test suite for the Rails app.
tags: [setup, dev, runbook]
generated:
  by: copilot-cli/claude-sonnet-5
  at: 2026-08-21T23:39:26Z
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
Yarn or npm, SQLite3 in development (PostgreSQL gem present for other
environments), Git.[^gemfile]

This is the environment used to run and test the system described in
[architecture/overview.md](/architecture/overview.md).

# Steps

```bash
bundle install && yarn install
bin/rails db:create db:migrate
./bin/dev                    # starts Rails server + Tailwind watch + JS bundler on :3000
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
