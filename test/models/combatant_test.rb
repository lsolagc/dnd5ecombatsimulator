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

  test "defenses reads and writes the three columns" do
    combatant = combatants(:aragorn_combatant)
    combatant.defenses = { "fire" => "R", "cold" => "I" }

    assert_equal({ "cold" => "I", "fire" => "R" }, combatant.defenses.to_h)
    assert combatant.resistances.dig("damage_types", "fire")
    assert_not combatant.immunities.dig("damage_types", "fire")
  end

  test "a damage type has one defense at most" do
    combatant = combatants(:aragorn_combatant)
    combatant.immunities["damage_types"]["fire"] = true
    combatant.resistances["damage_types"]["fire"] = true

    assert_not combatant.valid?
    assert_includes combatant.errors[:base], "Um tipo de dano tem uma defesa só (fire: imunidade e resistência)"

    combatant.vulnerabilities["damage_types"]["fire"] = true
    assert_not combatant.valid?
    assert_includes combatant.errors[:base], "Um tipo de dano tem uma defesa só (fire: imunidade, resistência e vulnerabilidade)"
  end
end
