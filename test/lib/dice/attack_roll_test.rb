require "test_helper"

class Dice::AttackRollTest < ActiveSupport::TestCase
  test "advantage rolls the to-hit d20 twice, keeps the higher, and rolls damage once" do
    Random.srand(42) # to-hit rolls: 7, then 20 (crit) -> damage rolled once and doubled

    attack = Dice::AttackRoll.new(to_hit_modifier: 0, damage_dice: "1d6", advantage: true)

    assert_equal 20, attack.total
    assert attack.crit
    assert_equal 10, attack.damage
  end

  test "disadvantage rolls the to-hit d20 twice, keeps the lower, and rolls damage once" do
    Random.srand(42) # to-hit rolls: 7, then 20 -> lower (7) is kept, no crit

    attack = Dice::AttackRoll.new(to_hit_modifier: 0, damage_dice: "1d6", disadvantage: true)

    assert_equal 7, attack.total
    refute attack.crit
    assert_equal 5, attack.damage
  end

  test "advantage and disadvantage cancel out into a single to-hit roll" do
    Random.srand(42)
    plain = Dice::AttackRoll.new(to_hit_modifier: 0, damage_dice: "1d6")

    Random.srand(42)
    cancelled = Dice::AttackRoll.new(to_hit_modifier: 0, damage_dice: "1d6", advantage: true, disadvantage: true)

    assert_equal plain.total, cancelled.total
    assert_equal plain.damage, cancelled.damage
  end

  test "exposes the natural d20 the total was built from" do
    Random.srand(42) # natural 7

    attack = Dice::AttackRoll.new(to_hit_modifier: 2, damage_dice: "1d4")

    assert_equal 7, attack.natural
    assert_equal 9, attack.total
  end

  test "neither advantage nor disadvantage rolls a single to-hit d20" do
    attack = Dice::AttackRoll.new(to_hit_modifier: 2, damage_dice: "1d4")

    assert_kind_of Integer, attack.total
  end
end
