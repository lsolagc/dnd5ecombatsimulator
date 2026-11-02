require "test_helper"
require "minitest/mock"

class Dice::D20RollTest < ActiveSupport::TestCase
  test "Dice.hit? follows the 5e rule: natural 20 always hits, natural 1 always misses, otherwise total >= AC" do
    assert Dice.hit?(natural: 20, total: 1, armor_class: 30)
    assert_not Dice.hit?(natural: 1, total: 99, armor_class: 5)
    assert Dice.hit?(natural: 10, total: 15, armor_class: 15)
    assert_not Dice.hit?(natural: 10, total: 14, armor_class: 15)
  end

  test "Dice.d20 returns a plain roll when advantage/disadvantage are not requested" do
    Random.srand(42) # natural 7

    roll = Dice.d20(modifier: 2)

    assert_kind_of Dice::RollResult, roll
    assert_equal 7, roll.natural
    assert_equal 9, roll.total
  end

  test "with_advantage rolls a second d20 and keeps the higher total" do
    Random.srand(42) # rolls: 7, then 20

    upgraded = Dice.d20(modifier: 0).with_advantage

    assert_equal 20, upgraded.natural
    assert_equal 20, upgraded.total
  end

  test "with_disadvantage rolls a second d20 and keeps the lower total" do
    Random.srand(42) # rolls: 7, then 20

    downgraded = Dice.d20(modifier: 0).with_disadvantage

    assert_equal 7, downgraded.natural
    assert_equal 7, downgraded.total
  end

  test "with_advantage/with_disadvantage apply the same modifier to the second roll" do
    Random.srand(42) # rolls: 7, then 20

    upgraded = Dice.d20(modifier: 3).with_advantage

    assert_equal 20, upgraded.natural
    assert_equal 23, upgraded.total
  end

  # Each Dice.d20 call takes the next natural from the list.
  def with_naturals(*naturals, &)
    Dice.stub(:d20, ->(modifier: 0) { natural = naturals.shift; Dice::D20Roll.new(natural:, total: natural + modifier, modifier:) }, &)
  end

  test "reroll_lower_die with disadvantage rerolls the lower die and keeps the lower of the other and the new one" do
    roll = with_naturals(4, 15, 9) { Dice.d20(modifier: 2).with_disadvantage.reroll_lower_die }

    assert_equal 9, roll.natural # 4 rerolled into 9; 15 stays; the lower counts
    assert_equal 11, roll.total
    assert_equal [ 15, 9 ], roll.rolls

    assert_equal 15, with_naturals(4, 15, 18) { Dice.d20.with_disadvantage.reroll_lower_die }.natural
  end

  test "reroll_lower_die with advantage rerolls the lower die and keeps the higher of the other and the new one" do
    assert_equal 12, with_naturals(12, 3, 7) { Dice.d20.with_advantage.reroll_lower_die }.natural # 3 rerolled into 7
    assert_equal 19, with_naturals(12, 3, 19) { Dice.d20.with_advantage.reroll_lower_die }.natural
  end

  test "reroll_lower_die on a single die rolls it again" do
    roll = with_naturals(4, 1) { Dice.d20(modifier: 3).reroll_lower_die }

    assert_equal 1, roll.natural
    assert_equal 4, roll.total
  end
end
