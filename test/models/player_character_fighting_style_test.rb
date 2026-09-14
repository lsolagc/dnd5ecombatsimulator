require "test_helper"

class PlayerCharacterFightingStyleTest < ActiveSupport::TestCase
  test "a character with no chosen fighting style gets no Fighting Style feature" do
    character = player_characters(:aragorn)
    slugs = unlocked_slugs(character)

    assert slugs.none? { |slug| slug.start_with?("fighting-style-") }
  end

  test "a character with Archery chosen has access to Archery only" do
    character = player_characters(:fighter_archer)
    slugs = unlocked_slugs(character)

    assert_includes slugs, "fighting-style-archery"
    assert_not_includes slugs, "fighting-style-defense"
    assert_not_includes slugs, "fighting-style-dueling"
  end

  test "a character with Defense chosen has access to Defense only" do
    character = player_characters(:fighter_defender)
    slugs = unlocked_slugs(character)

    assert_includes slugs, "fighting-style-defense"
    assert_not_includes slugs, "fighting-style-archery"
    assert_not_includes slugs, "fighting-style-dueling"
  end

  test "a character with Dueling chosen has access to Dueling only" do
    character = player_characters(:fighter_duelist)
    slugs = unlocked_slugs(character)

    assert_includes slugs, "fighting-style-dueling"
    assert_not_includes slugs, "fighting-style-archery"
    assert_not_includes slugs, "fighting-style-defense"
  end

  test "fighting_style must be an optional-type class feature" do
    fighter = player_classes(:fighter)
    character = PlayerCharacter.new(
      name: "Bad Fighting Style",
      level: 1,
      player_class: fighter,
      fighting_style: class_features(:fighter_second_wind)
    )

    assert_not character.valid?
    assert_includes character.errors.attribute_names, :fighting_style
  end

  test "fighting_style must belong to the character's own class" do
    wizard = player_classes(:wizard)
    character = PlayerCharacter.new(
      name: "Cross Class Fighting Style",
      level: 1,
      player_class: wizard,
      fighting_style: class_features(:fighter_fighting_style_archery)
    )

    assert_not character.valid?
    assert_includes character.errors.attribute_names, :fighting_style
  end

  private

    def unlocked_slugs(character)
      character.send(:unlocked_class_feature_unlocks).map { |unlock| unlock.class_feature.slug }
    end
end
