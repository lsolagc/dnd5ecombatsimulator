require "test_helper"

class CombatantTest < ActiveSupport::TestCase
  test "basic attack fields default to the legacy fixed values" do
    combatant = combatants(:aragorn_combatant)

    assert_equal 0, combatant.attack_bonus
    assert_equal "1d4", combatant.damage_dice
    assert_equal "bludgeoning", combatant.damage_type
  end

  test "damage_type must be one of the known damage types" do
    combatant = combatants(:aragorn_combatant)
    combatant.damage_type = "not-a-real-type"

    assert_not combatant.valid?
    assert_includes combatant.errors.attribute_names, :damage_type
  end
end
