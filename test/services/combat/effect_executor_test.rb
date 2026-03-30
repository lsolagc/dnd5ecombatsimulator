require "test_helper"

class Combat::EffectExecutorTest < ActiveSupport::TestCase
  setup do
    @fighter = player_characters(:aragorn) # max_hit_points: 12, strength: 15 (mod +2)
    @fighter.current_hit_points = 5
  end

  test "heal effect increases target HP" do
    Random.srand(1)
    effect = Combat::EffectInstance.new(kind: :heal, roll_expression: "1d4", target_type: "self")

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: @fighter)

    assert_equal :heal, result.kind
    assert result.applied
    assert_equal 5, result.hp_before
    assert result.hp_after > 5
    assert result.hp_after <= @fighter.max_hit_points
  end

  test "heal effect caps at max HP" do
    @fighter.current_hit_points = 11 # 1 below max

    effect = Combat::EffectInstance.new(kind: :heal, roll_expression: "1d10", target_type: "self")

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: @fighter)

    assert_equal @fighter.max_hit_points, result.hp_after
  end

  test "heal effect includes roll_outcome breakdown" do
    Random.srand(1)
    effect = Combat::EffectInstance.new(kind: :heal, roll_expression: "1d10 + actor_level", target_type: "self")

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: @fighter)

    assert_instance_of Combat::RollOutcome, result.roll_outcome
    assert_equal "1d10 + actor_level", result.roll_outcome.expression
    assert result.roll_outcome.total >= 2 # min 1d10(1) + level(1)
  end

  test "heal effect returns a descriptive message" do
    Random.srand(1)
    effect = Combat::EffectInstance.new(kind: :heal, roll_expression: "1d4", target_type: "self")

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: @fighter)

    assert_includes result.message, @fighter.name
    assert_includes result.message, "heals"
  end

  test "damage effect reduces target HP" do
    Random.srand(1)
    effect = Combat::EffectInstance.new(
      kind: :damage,
      roll_expression: "1d4",
      target_type: "target",
      damage_type: "fire"
    )
    target = player_characters(:aragorn_copy)
    target.current_hit_points = target.max_hit_points

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: target)

    assert_equal :damage, result.kind
    assert result.hp_after < result.hp_before
  end

  test "damage effect defaults to bludgeoning damage type" do
    target = player_characters(:aragorn_copy)
    target.current_hit_points = target.max_hit_points
    hp_before = target.current_hit_points

    effect = Combat::EffectInstance.new(kind: :damage, roll_expression: "1d4", target_type: "target")

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: target)

    assert result.hp_after < hp_before
  end

  test "raises for unknown effect kind" do
    effect = Combat::EffectInstance.new(kind: :unknown_kind, roll_expression: "1d4", target_type: "self")

    assert_raises(ArgumentError) do
      Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: @fighter)
    end
  end
end
