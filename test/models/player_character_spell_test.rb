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

  test "an Eldritch Knight cannot prepare a spell outside abjuration or evocation" do
    out_of_school = PlayerCharacterSpell.new(
      player_character: player_characters(:eldritch_knight_seven),
      spell: spells(:mage_hand) # conjuration
    )

    assert_not out_of_school.valid?
    assert_includes out_of_school.errors[:spell], "must be abjuration or evocation for an Eldritch Knight"
  end

  test "a non-Eldritch-Knight character is not restricted by school" do
    unrestricted = PlayerCharacterSpell.new(
      player_character: player_characters(:aragorn),
      spell: spells(:mage_hand) # conjuration, no spellcasting feature on this character anyway
    )

    assert unrestricted.valid?
  end

  test "cannot prepare a spell beyond the character's spells_known limit" do
    # eldritch_knight_seven's fixtures already carry 3 known spells (magic_missile,
    # shield, chromatic_orb) against the level 3 progression's spells_known: 3 limit.
    over_the_limit = PlayerCharacterSpell.new(
      player_character: player_characters(:eldritch_knight_seven),
      spell: spells(:fireball)
    )

    assert_not over_the_limit.valid?
    assert_includes over_the_limit.errors[:spell], "exceeds the number of spells known (3)"
  end
end
