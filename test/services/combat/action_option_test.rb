require "test_helper"

class Combat::ActionOptionTest < ActiveSupport::TestCase
  test "is immutable and equal by value, so the turn AI can subtract and sample options like the hashes they replace" do
    spell = spells(:magic_missile)
    option = Combat::ActionOption.new(type: :cast_spell, spell:, payload: { "target" => "enemy" })

    assert option.frozen?
    assert_not_respond_to option, :target=
    assert_equal option, Combat::ActionOption.new(type: :cast_spell, spell:, payload: { "target" => "enemy" })
    assert_equal option.hash, Combat::ActionOption.new(type: :cast_spell, spell:, payload: { "target" => "enemy" }).hash
    assert_equal [ Combat::ActionOption.new(type: :attack) ], [ Combat::ActionOption.new(type: :attack), option ] - [ option ]
  end

  test "a gambit's pick is the same option with the rule's target and gambit, the original untouched" do
    option = Combat::ActionOption.new(type: :attack)
    gambit = Gambit.new(position: 1)
    target = player_characters(:aragorn)

    chosen = option.with(target:, gambit:)

    assert chosen.chosen_by_gambit?
    assert_equal [ target, gambit ], [ chosen.target, chosen.gambit ]
    assert_not option.chosen_by_gambit?
    assert_nil option.target
    assert_not_equal option, chosen
  end

  test "predicates read the type and payload" do
    maneuver = Combat::ActionOption.new(type: :class_feature, payload: { "applies_to" => "weapon_attack" })
    feature = Combat::ActionOption.new(type: :class_feature, payload: { "kind" => "heal" })

    assert maneuver.maneuver?
    assert_not feature.maneuver?
    assert Combat::ActionOption.new(type: :cast_spell).spell?
    assert_not feature.spell?
    assert Combat::ActionOption.new(type: :action_surge).action_surge?
    assert_not Combat::ActionOption.new(type: :attack).action_surge?
  end
end
