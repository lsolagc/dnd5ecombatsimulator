require "test_helper"

class Combatant::DefensesTest < ActiveSupport::TestCase
  Defenses = Combatant::Defenses

  test "of reads the defended types from the combatant's columns" do
    combatant = combatants(:aragorn_combatant)
    combatant.immunities["damage_types"]["cold"] = true
    combatant.vulnerabilities["damage_types"]["fire"] = true

    assert_equal({ "cold" => "I", "fire" => "V" }, Defenses.of(combatant).to_h)
    assert_equal({}, Defenses.of(combatants(:merlin_combatant)).to_h)
  end

  test "of reads an immunity over a resistance over a vulnerability" do
    combatant = combatants(:aragorn_combatant)
    %w[immunities resistances vulnerabilities].each { |column| combatant[column]["damage_types"]["fire"] = true }
    combatant.resistances["damage_types"]["cold"] = true
    combatant.vulnerabilities["damage_types"]["cold"] = true

    assert_equal({ "cold" => "R", "fire" => "I" }, Defenses.of(combatant).to_h.sort.to_h)
  end

  test "flag takes a string or a symbol and is nil without a defense" do
    defenses = Defenses.new("fire" => "R")

    assert_equal "R", defenses.flag("fire")
    assert_equal "R", defenses.flag(:fire)
    assert_nil defenses.flag(:cold)
    assert_nil defenses.flag(nil)
  end

  test "predicates" do
    defenses = Defenses.new(cold: "I", fire: "R", acid: "V")

    assert defenses.immune_to?(:cold)
    assert defenses.resistant_to?("fire")
    assert defenses.vulnerable_to?(:acid)
    assert_not defenses.immune_to?(:fire)
    assert_not defenses.resistant_to?(:thunder)
  end

  test "apply: immunity takes nothing, resistance halves rounding down, vulnerability doubles" do
    defenses = Defenses.new("cold" => "I", "fire" => "R", "acid" => "V")

    assert_equal 0, defenses.apply(7, "cold")
    assert_equal 3, defenses.apply(7, :fire)
    assert_equal 14, defenses.apply(7, "acid")
    assert_equal 7, defenses.apply(7, "thunder")
    assert_equal 7, defenses.apply(7, nil)
    assert_equal 7, defenses.apply(7, "not-a-type")
  end

  test "rejects an unknown damage type or flag" do
    assert_raises(ArgumentError) { Defenses.new("lava" => "R") }
    assert_raises(ArgumentError) { Defenses.new("fire" => "X") }
    assert_raises(ArgumentError) { Defenses.new("fire" => "") }
  end

  test "columns_for writes every damage type and leaves conditions untouched" do
    combatant = combatants(:aragorn_combatant)
    combatant.resistances["damage_types"]["cold"] = true
    combatant.resistances["conditions"]["fear"] = true

    columns = Defenses.new("fire" => "R").columns_for(combatant)

    assert_equal Defenses::FLAGS.values.sort, columns.keys.sort
    assert_equal Defenses::TYPES.sort, columns["resistances"]["damage_types"].keys.sort
    assert columns["resistances"]["damage_types"]["fire"]
    assert_not columns["resistances"]["damage_types"]["cold"]
    assert_not columns["immunities"]["damage_types"]["fire"]
    assert columns["resistances"]["conditions"]["fear"]
    assert_equal combatant.immunities["conditions"], columns["immunities"]["conditions"]
  end
end
