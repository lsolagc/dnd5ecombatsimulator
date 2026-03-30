require "test_helper"

class Combat::RollExpressionTest < ActiveSupport::TestCase
  setup do
    @context = Combat::RollContext.new(actor: player_characters(:aragorn))
    player_characters(:aragorn).current_hit_points = player_characters(:aragorn).max_hit_points
  end

  test "rolls a simple dice expression" do
    Random.srand(1)
    outcome = Combat::RollExpression.new(expression: "1d10").resolve(context: @context)

    assert_equal 1, outcome.dice.size
    assert_equal "1d10", outcome.dice.first
    assert_equal 1, outcome.rolls.size
    assert_includes 1..10, outcome.total
  end

  test "rolls dice with a numeric modifier" do
    Random.srand(1)
    outcome = Combat::RollExpression.new(expression: "1d6 + 3").resolve(context: @context)

    assert_includes 4..9, outcome.total
  end

  test "subtracts a numeric modifier" do
    Random.srand(42)
    outcome = Combat::RollExpression.new(expression: "1d4 - 1").resolve(context: @context)

    assert_includes 0..3, outcome.total
  end

  test "resolves actor_level variable" do
    # aragorn is level 1
    Random.srand(1)
    outcome = Combat::RollExpression.new(expression: "1d10 + actor_level").resolve(context: @context)

    assert_includes 2..11, outcome.total
    assert_equal 1, outcome.modifiers["actor_level"]
  end

  test "resolves fighter_level as actor level" do
    Random.srand(1)
    outcome = Combat::RollExpression.new(expression: "1d10 + fighter_level").resolve(context: @context)

    assert_equal 1, outcome.modifiers["fighter_level"]
  end

  test "resolves strength_modifier" do
    # aragorn has strength 15 → modifier = +2
    Random.srand(1)
    outcome = Combat::RollExpression.new(expression: "1d4 + strength_modifier").resolve(context: @context)

    assert_equal 2, outcome.modifiers["strength_modifier"]
  end

  test "returns detailed roll outcome with expression info" do
    Random.srand(1)
    outcome = Combat::RollExpression.new(expression: "1d10 + actor_level").resolve(context: @context)

    assert_equal "1d10 + actor_level", outcome.expression
    assert_match(/1d10\+1/, outcome.resolved_expression)
  end

  test "raises on unrecognized term" do
    assert_raises(ArgumentError) do
      # "4abc" starts with a digit but is not a valid dice/number/variable token
      Combat::RollExpression.new(expression: "1d10 + 4abc").resolve(context: @context)
    end
  end
end
