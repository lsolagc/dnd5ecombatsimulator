require "test_helper"

class SeedDataTest < ActiveSupport::TestCase
  MODELS = [ PlayerClass, ClassLevelProgression, ClassFeature, ClassFeatureUnlock, Spell, SpellSlotProgression,
             PlayerCharacter, PlayerCharacterSpell, PlayerCharacterManeuver ].freeze

  test "loads the classes, progressions, features, spells and characters from db/seeds" do
    SeedData.load_all

    fighter = PlayerClass.find_by!(name: "Guerreiro")
    assert_equal 2, fighter.progression_at(5).attacks_per_action
    assert fighter.progression_at(19).grants_ability_score_improvement?

    knight = PlayerCharacter.find_by!(name: "Cavaleiro Arcano")
    assert_equal({ 1 => 2, 2 => 0, 3 => 0, 4 => 0 }, knight.available_spell_slots)
    assert_equal %w[ chromatic-orb fire-bolt ray-of-frost shield ], knight.spells.pluck(:slug).sort
    assert_equal "intelligence", knight.spellcasting_ability

    battle_master = PlayerCharacter.find_by!(name: "Mestre de Batalha")
    assert_equal 3, battle_master.known_maneuvers.count
    assert_equal 19, PlayerCharacter.find_by!(name: "Campeão").critical_hit_threshold
  end

  test "running it twice creates nothing new" do
    SeedData.load_all
    counts = MODELS.index_with(&:count)

    SeedData.load_all

    assert_equal counts, MODELS.index_with(&:count)
  end

  test "the templates are loadable" do
    templates = SeedData::ROOT.join("templates")

    SeedData.load_class(templates.join("class.yml"))
    SeedData.load_all # the character template refers to the real Guerreiro seeds
    SeedData.load_character(templates.join("character.yml"))

    assert_equal [ 3 ], ClassFeature.find_by!(slug: "conjuracao-da-subclasse").spell_slot_progressions.pluck(:level)
    assert_equal "Personagem de Exemplo", PlayerCharacter.last.name
  end

  test "an unknown key is rejected instead of silently ignored" do
    file = Tempfile.new([ "class", ".yml" ]).tap { |f| f.write("name: X\nhit_die: d6\nfeatuers: []\n"); f.close }

    assert_raises(ArgumentError) { SeedData.load_class(file.path) }
  end
end
