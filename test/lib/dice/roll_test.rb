require "test_helper"

class Dice::RollTest < ActiveSupport::TestCase
  test "a crit rolls twice the dice and adds the modifier once" do
    result = Dice.roll(dice: "3d1", modifier: 4, crit: true)

    assert_equal [ 1 ] * 6, result.rolls
    assert_equal 6, result.natural
    assert_equal 10, result.total
  end
end
