require "test_helper"

class PlayerCharacterSpellTest < ActiveSupport::TestCase
  test "a character cannot prepare the same spell twice" do
    duplicate = PlayerCharacterSpell.new(
      player_character: player_characters(:merlin),
      spell: spells(:fire_bolt)
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:spell_id], "has already been taken"
  end

  test "the same spell can be prepared by different characters" do
    other = PlayerCharacterSpell.new(
      player_character: player_characters(:aragorn),
      spell: spells(:fire_bolt)
    )

    assert other.valid?
  end
end
