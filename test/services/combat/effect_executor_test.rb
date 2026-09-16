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

  test "damage effect with a save applies full damage when the target fails" do
    Random.srand(1) # 1d10 roll = 6, target's dexterity save total = 13
    effect = Combat::EffectInstance.new(
      kind: :damage,
      roll_expression: "1d10",
      target_type: "target",
      save: { "ability" => "dexterity", "dc" => 20, "on_success" => "half" }
    )
    target = player_characters(:aragorn_copy)
    target.current_hit_points = target.max_hit_points

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: target)

    refute result.saving_throw.success
    assert_equal 6, result.amount
    assert_includes result.message, "fails the dexterity save"
  end

  test "damage effect with a save applies half damage when the target succeeds" do
    Random.srand(1) # 1d10 roll = 6, target's dexterity save total = 13
    effect = Combat::EffectInstance.new(
      kind: :damage,
      roll_expression: "1d10",
      target_type: "target",
      save: { "ability" => "dexterity", "dc" => 5, "on_success" => "half" }
    )
    target = player_characters(:aragorn_copy)
    target.current_hit_points = target.max_hit_points

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: target)

    assert result.saving_throw.success
    assert_equal 3, result.amount
    assert_includes result.message, "succeeds the dexterity save"
  end

  test "damage effect with a save negates damage entirely on success" do
    Random.srand(1) # 1d10 roll = 6, target's dexterity save total = 13
    effect = Combat::EffectInstance.new(
      kind: :damage,
      roll_expression: "1d10",
      target_type: "target",
      save: { "ability" => "dexterity", "dc" => 5, "on_success" => "negate" }
    )
    target = player_characters(:aragorn_copy)
    hp_before = target.current_hit_points = target.max_hit_points

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: target)

    assert result.saving_throw.success
    assert_equal 0, result.amount
    assert_equal hp_before, result.hp_after
  end

  test "reroll_saving_throw reflects the second roll when the first save fails" do
    Random.srand(26) # 1d10 roll = 6; 1st dexterity save total 8 (fails dc 10); reroll total 18 (succeeds)
    effect = Combat::EffectInstance.new(
      kind: :damage,
      roll_expression: "1d10",
      target_type: "target",
      save: { "ability" => "dexterity", "dc" => 10, "on_success" => "half" }
    )
    target = player_characters(:aragorn_copy)
    target.current_hit_points = target.max_hit_points

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: target, reroll_saving_throw: true)

    assert result.saving_throw.rerolled
    assert result.saving_throw.success
    assert_equal 3, result.amount
  end

  test "reroll_saving_throw does not reroll a save that succeeds on the first attempt" do
    Random.srand(1) # 1d10 roll = 6; dexterity save total 13, succeeds dc 5 on the first attempt
    effect = Combat::EffectInstance.new(
      kind: :damage,
      roll_expression: "1d10",
      target_type: "target",
      save: { "ability" => "dexterity", "dc" => 5, "on_success" => "half" }
    )
    target = player_characters(:aragorn_copy)
    target.current_hit_points = target.max_hit_points

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: target, reroll_saving_throw: true)

    refute result.saving_throw.rerolled
    assert_equal 3, result.amount
  end

  test "heal effect without a save leaves saving_throw nil" do
    Random.srand(1)
    effect = Combat::EffectInstance.new(kind: :heal, roll_expression: "1d4", target_type: "self")

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: @fighter)

    assert_nil result.saving_throw
  end
end
