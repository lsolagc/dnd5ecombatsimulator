require "test_helper"

class Dice::D20RollTest < ActiveSupport::TestCase
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
end
