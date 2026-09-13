require "test_helper"

class PlayerCharacterMartialArchetypeTest < ActiveSupport::TestCase
  test "a character with no chosen archetype gets no subclass or subclass_progression features" do
    character = player_characters(:fighter_no_archetype_seven)
    feature_types = unlocked_slugs_and_types(character).map { |_, type| type }

    assert feature_types.none? { |type| type.in?(%w[subclass subclass_progression]) }
    assert_nil character.spellcasting_feature
  end

  test "core features are always visible regardless of archetype" do
    character = player_characters(:fighter_no_archetype_seven)
    slugs = unlocked_slugs(character)

    assert_includes slugs, "second-wind"
    assert_includes slugs, "action-surge"
  end

  test "a Champion has access to Champion features only" do
    character = player_characters(:champion_seven)
    slugs = unlocked_slugs(character)

    assert_includes slugs, "martial-archetype-champion"
    assert_includes slugs, "champion-improved-critical"
    assert_includes slugs, "champion-remarkable-athlete"
    assert_not_includes slugs, "battle-master-combat-superiority"
    assert_not_includes slugs, "eldritch-knight-spellcasting"
    assert_nil character.spellcasting_feature
  end

  test "a Battle Master has access to Battle Master features only" do
    character = player_characters(:battle_master_seven)
    slugs = unlocked_slugs(character)

    assert_includes slugs, "battle-master-combat-superiority"
    assert_not_includes slugs, "champion-improved-critical"
    assert_not_includes slugs, "eldritch-knight-spellcasting"
    assert_nil character.spellcasting_feature
  end

  test "an Eldritch Knight has access to Eldritch Knight features only, including spellcasting" do
    character = player_characters(:eldritch_knight_seven)
    slugs = unlocked_slugs(character)

    assert_includes slugs, "eldritch-knight-spellcasting"
    assert_not_includes slugs, "champion-improved-critical"
    assert_not_includes slugs, "battle-master-combat-superiority"
    assert_equal "eldritch-knight-spellcasting", character.spellcasting_feature.slug
  end

  test "martial_archetype must be a subclass-type feature" do
    fighter = player_classes(:fighter)
    character = PlayerCharacter.new(
      name: "Bad Archetype",
      level: 3,
      player_class: fighter,
      martial_archetype: class_features(:fighter_champion_improved_critical)
    )

    assert_not character.valid?
    assert_includes character.errors.attribute_names, :martial_archetype
  end

  test "martial_archetype must belong to the character's own class" do
    wizard = player_classes(:wizard)
    character = PlayerCharacter.new(
      name: "Cross Class Archetype",
      level: 3,
      player_class: wizard,
      martial_archetype: class_features(:fighter_champion_archetype)
    )

    assert_not character.valid?
    assert_includes character.errors.attribute_names, :martial_archetype
  end

  private

    def unlocked_slugs_and_types(character)
      character.send(:unlocked_class_feature_unlocks).map { |unlock| [ unlock.class_feature.slug, unlock.class_feature.feature_type ] }
    end

    def unlocked_slugs(character)
      unlocked_slugs_and_types(character).map(&:first)
    end
end
