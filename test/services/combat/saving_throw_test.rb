require "test_helper"
require "minitest/mock"

class Combat::SavingThrowTest < ActiveSupport::TestCase
  INDOMITABLE = Combat::Reroll.new(class_feature_id: -1, when: "failed")

  setup do
    @aragorn = player_characters(:aragorn) # dexterity: 12 (mod +1)
  end

  test "succeeds when total meets the dc" do
    Random.srand(42) # natural 7, total 8 with dex modifier +1
    save = Combat::SavingThrow.new(actor: @aragorn, ability: "dexterity", dc: 8)

    assert_equal "dexterity", save.ability
    assert_equal 8, save.dc
    assert_equal 7, save.natural
    assert_equal 8, save.total
    assert save.success
  end

  test "fails when total is below the dc" do
    Random.srand(42) # natural 7, total 8 with dex modifier +1
    save = Combat::SavingThrow.new(actor: @aragorn, ability: "dexterity", dc: 9)

    refute save.success
  end

  test "advantage rolls twice and keeps the higher total" do
    Random.srand(42) # rolls: 7, then 20
    save = Combat::SavingThrow.new(actor: @aragorn, ability: "dexterity", dc: 10, advantage: true)

    assert_equal 20, save.natural
    assert_equal 21, save.total
    assert save.success
  end

  test "disadvantage rolls twice and keeps the lower total" do
    Random.srand(42) # rolls: 7, then 20
    save = Combat::SavingThrow.new(actor: @aragorn, ability: "dexterity", dc: 10, disadvantage: true)

    assert_equal 7, save.natural
    assert_equal 8, save.total
    refute save.success
  end

  test "advantage and disadvantage cancel out into a single roll" do
    Random.srand(42)
    plain = Combat::SavingThrow.new(actor: @aragorn, ability: "dexterity", dc: 10)

    Random.srand(42)
    cancelled = Combat::SavingThrow.new(actor: @aragorn, ability: "dexterity", dc: 10, advantage: true, disadvantage: true)

    assert_equal plain.natural, cancelled.natural
    assert_equal plain.total, cancelled.total
  end

  test "a reroll applies to a failed save, which takes the new roll's result, and is listed as used" do
    Random.srand(1) # rolls: natural 6 (total 7, fails dc 10), then natural 12 (total 13, succeeds)
    save = Combat::SavingThrow.new(actor: @aragorn, ability: "dexterity", dc: 10, rerolls: [ INDOMITABLE ])

    assert save.rerolled
    assert_equal [ INDOMITABLE ], save.rerolls_used
    assert_equal 12, save.natural
    assert_equal 13, save.total
    assert save.success
  end

  test "a save that already succeeded uses no reroll" do
    Random.srand(42) # natural 7, total 8, succeeds dc 8
    save = Combat::SavingThrow.new(actor: @aragorn, ability: "dexterity", dc: 8, rerolls: [ INDOMITABLE ])

    refute save.rerolled
    assert_empty save.rerolls_used
    assert_equal 7, save.natural
    assert_equal 8, save.total
  end

  test "does not reroll a failed save by default" do
    Random.srand(42) # natural 7, total 8, fails dc 9
    save = Combat::SavingThrow.new(actor: @aragorn, ability: "dexterity", dc: 9)

    refute save.rerolled
    assert_equal 7, save.natural
    assert_equal 8, save.total
  end

  test "each reroll is used at most once, in order, until the save passes" do
    other = Combat::Reroll.new(class_feature_id: -2, when: "failed")
    save = with_naturals(2, 3, 18, 1) { Combat::SavingThrow.new(actor: @aragorn, ability: "dexterity", dc: 10, rerolls: [ INDOMITABLE, other, other ]) }

    assert_equal [ INDOMITABLE, other ], save.rerolls_used # 2 → 3 (fails) → 18 (passes); the third one is not used
    assert_equal 18, save.natural
  end

  test "a failed save with disadvantage rerolls only the lower die and keeps the lower of the two left" do
    save = with_naturals(3, 16, 12) { Combat::SavingThrow.new(actor: @aragorn, ability: "dexterity", dc: 15, disadvantage: true, rerolls: [ INDOMITABLE ]) }

    assert save.rerolled
    assert_equal 12, save.natural # 3 rerolled into 12; 16 stays; the lower counts
    assert_equal 13, save.total
    refute save.success
  end

  private

    # Each Dice.d20 call takes the next natural from the list.
    def with_naturals(*naturals, &)
      Dice.stub(:d20, ->(modifier: 0) { natural = naturals.shift; Dice::D20Roll.new(natural:, total: natural + modifier, modifier:) }, &)
    end
end
