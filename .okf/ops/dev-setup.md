---
type: Runbook
title: Local development setup
description: Install, database setup, running the dev server, and running the test suite for the Rails app.
tags: [setup]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-11T22:30:00Z
verified: { by: human:lsolagc, at: 2026-10-11T21:31:53Z }
sources:
  - id: gemfile
    title: Gemfile / .ruby-version
    resource: ../../Gemfile
  - id: compose
    title: compose.yaml / Dockerfile.dev / bin/okf-server
    resource: ../../compose.yaml
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

# Always-on stack (Docker Compose)

`compose.yaml` runs the same thing without a terminal to keep open: Postgres 16
(service `db`, its own volume, not published to the host), the portal through
`bin/dev` (service `app`: web on :3000, Sass watcher, Solid Queue workers) and
the OKF viewer (service `okf`, :8808). The code is bind-mounted; the app's gems
live in a `bundle` volume and `bin/rails db:prepare` (create, migrate, seed)
runs on every start. `bin/okf-server` restarts `okf server` whenever a file
under `.okf/` changes, since the server parses the bundle once. Everything has
`restart: unless-stopped`, so it comes back whenever Docker starts.[^compose]

```bash
docker compose up -d                         # once; rebuild with --build after changing Dockerfile.dev
docker compose logs -f app                   # server, jobs and Sass output
docker compose exec app bin/rails console    # any rails/rake command, credentials already set
docker compose restart app                   # after a Gemfile or config/ change
docker compose exec app bin/rails test       # the suite, against the container's dnd_test
docker compose exec app bin/rails test:system  # system tests, headless Chromium in the image
```

The containers run as UID 1000 (build arg `UID`), so files they write in the
repo stay owned by the host user. Ports 3000 and 8808 must be free: stop a
local `bin/dev` or `okf server` first. Tests run in the container or on the
host: `DB_HOST` points the test database at whichever Postgres the shell sees
(`db` in the container, `localhost` by default), so each has its own `dnd_test`.
The image's Chromium runs with `--no-sandbox` (set in `/etc/chromium.d/`), since
Docker's default seccomp profile blocks its sandbox. To bring the host's
development data into the container, restore a dump into the `db` service, e.g.
`pg_dump -Fc dnd_development | docker compose exec -T db pg_restore -U postgres -d dnd_development --clean --if-exists`.

On WSL, Docker Desktop needs *Settings → Resources → WSL integration* turned on
for the distro, and *Start Docker Desktop when you sign in* for the stack to be
up after a reboot.

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
[gambits-decisions.md](/architecture/gambits-decisions.md), "Dev characters"). Found by exact
name; replaces only their gambits, in one transaction, so running it again is a
no-op — and also undoes manual edits made to their rules since.

[^gemfile]: Source: `Gemfile / .ruby-version`
[^compose]: Source: `compose.yaml / Dockerfile.dev / bin/okf-server`
