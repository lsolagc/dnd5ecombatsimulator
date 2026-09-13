require "test_helper"

class Combat::SavingThrowTest < ActiveSupport::TestCase
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
end
