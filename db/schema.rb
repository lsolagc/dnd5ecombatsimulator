# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_07_22_235034) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "combatants", force: :cascade do |t|
    t.integer "armor_class", default: 10, null: false
    t.integer "strength", default: 10, null: false
    t.integer "dexterity", default: 10, null: false
    t.integer "constitution", default: 10, null: false
    t.integer "intelligence", default: 10, null: false
    t.integer "wisdom", default: 10, null: false
    t.integer "charisma", default: 10, null: false
    t.integer "speed", default: 30, null: false
    t.integer "proficiency_bonus", default: 2, null: false
    t.jsonb "vulnerabilities", default: {"conditions" => {"fear" => false, "stun" => false, "charm" => false, "prone" => false, "grapple" => false, "deafness" => false, "blindness" => false, "paralysis" => false, "poisoning" => false, "restraint" => false, "exhaustion" => false, "invisibility" => false, "petrification" => false, "incapacitation" => false, "unconsciousness" => false}, "damage_types" => {"acid" => false, "cold" => false, "fire" => false, "force" => false, "poison" => false, "psychic" => false, "radiant" => false, "thunder" => false, "necrotic" => false, "piercing" => false, "slashing" => false, "lightning" => false, "bludgeoning" => false}}
    t.jsonb "resistances", default: {"conditions" => {"fear" => false, "stun" => false, "charm" => false, "prone" => false, "grapple" => false, "deafness" => false, "blindness" => false, "paralysis" => false, "poisoning" => false, "restraint" => false, "exhaustion" => false, "invisibility" => false, "petrification" => false, "incapacitation" => false, "unconsciousness" => false}, "damage_types" => {"acid" => false, "cold" => false, "fire" => false, "force" => false, "poison" => false, "psychic" => false, "radiant" => false, "thunder" => false, "necrotic" => false, "piercing" => false, "slashing" => false, "lightning" => false, "bludgeoning" => false}}
    t.jsonb "immunities", default: {"conditions" => {"fear" => false, "stun" => false, "charm" => false, "prone" => false, "grapple" => false, "deafness" => false, "blindness" => false, "paralysis" => false, "poisoning" => false, "restraint" => false, "exhaustion" => false, "invisibility" => false, "petrification" => false, "incapacitation" => false, "unconsciousness" => false}, "damage_types" => {"acid" => false, "cold" => false, "fire" => false, "force" => false, "poison" => false, "psychic" => false, "radiant" => false, "thunder" => false, "necrotic" => false, "piercing" => false, "slashing" => false, "lightning" => false, "bludgeoning" => false}}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "player_classes", force: :cascade do |t|
    t.string "name"
    t.integer "hit_die", default: 0, null: false
    t.text "description"
    t.integer "spellcasting_modifier"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
