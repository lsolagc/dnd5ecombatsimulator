require "test_helper"

class PlayerCharacterManeuverTest < ActiveSupport::TestCase
  test "a duplicate known maneuver for the same character is invalid" do
    maneuver = PlayerCharacterManeuver.new(
      player_character: player_characters(:battle_master_seven),
      maneuver: class_features(:fighter_battle_master_maneuver_precision_attack)
    )

    assert_not maneuver.valid?
    assert_includes maneuver.errors.attribute_names, :maneuver_id
  end

  test "a feature that is not a Battle Master maneuver cannot be known as one" do
    maneuver = PlayerCharacterManeuver.new(
      player_character: player_characters(:battle_master_seven),
      maneuver: class_features(:fighter_second_wind)
    )

    assert_not maneuver.valid?
    assert_includes maneuver.errors.attribute_names, :maneuver
  end

  test "a maneuver cannot be known by a character of a different class" do
    maneuver = PlayerCharacterManeuver.new(
      player_character: player_characters(:merlin),
      maneuver: class_features(:fighter_battle_master_maneuver_precision_attack)
    )

    assert_not maneuver.valid?
    assert_includes maneuver.errors.attribute_names, :maneuver
  end

  test "known_maneuvers_limit follows the Battle Master maneuvers-known table" do
    assert_equal 0, PlayerCharacterManeuver.known_maneuvers_limit(level: 1)
    assert_equal 3, PlayerCharacterManeuver.known_maneuvers_limit(level: 3)
    assert_equal 3, PlayerCharacterManeuver.known_maneuvers_limit(level: 6)
    assert_equal 5, PlayerCharacterManeuver.known_maneuvers_limit(level: 7)
    assert_equal 7, PlayerCharacterManeuver.known_maneuvers_limit(level: 10)
    assert_equal 9, PlayerCharacterManeuver.known_maneuvers_limit(level: 15)
  end
end
