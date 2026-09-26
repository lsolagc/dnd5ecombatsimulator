# Seed data lives in YAML under db/seeds/ (spells.yml, classes/*.yml, characters/*.yml); the formats
# are documented in db/seeds/templates/. Idempotent, so it can be run at any point in every environment.
SeedData.load_all
