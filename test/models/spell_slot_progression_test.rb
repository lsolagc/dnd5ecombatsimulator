require "test_helper"

class SpellSlotProgressionTest < ActiveSupport::TestCase
  test "slots_for returns the slot count for a given spell level" do
    progression = spell_slot_progressions(:wizard_spellcasting_level_1)

    assert_equal 2, progression.slots_for(1)
    assert_equal 0, progression.slots_for(2)
  end

  test "slots_for returns 0 outside the supported 1..4 range" do
    progression = spell_slot_progressions(:wizard_spellcasting_level_1)

    assert_equal 0, progression.slots_for(0)
    assert_equal 0, progression.slots_for(5)
  end

  test "slots_by_level returns a hash covering levels 1 through 4" do
    progression = spell_slot_progressions(:wizard_spellcasting_level_1)

    assert_equal({ 1 => 2, 2 => 0, 3 => 0, 4 => 0 }, progression.slots_by_level)
  end

  test "level is unique per class feature" do
    duplicate = SpellSlotProgression.new(
      class_feature: class_features(:wizard_spellcasting),
      level: spell_slot_progressions(:wizard_spellcasting_level_1).level
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:level], "has already been taken"
  end
end
