require "test_helper"

class Combat::ActionRunnerTest < ActiveSupport::TestCase
  setup do
    @fighter = player_characters(:aragorn) # level 1 fighter, max_hit_points: 12
    @fighter.current_hit_points = 4 # simulate damage taken
  end

  test "executes Second Wind to heal the fighter" do
    Random.srand(1)
    feature = class_features(:fighter_second_wind)

    action = Combat::CombatAction.new(
      source_type: :class_feature,
      source_id:   feature.id,
      actor:       @fighter,
      targets:     []
    )

    results = Combat::ActionRunner.call(action: action)

    assert_equal 1, results.size
    result = results.first

    assert_equal :heal, result.kind
    assert result.applied
    assert_equal 4, result.hp_before
    assert result.hp_after > 4
    assert result.hp_after <= @fighter.max_hit_points
  end

  test "Second Wind roll includes actor_level as modifier" do
    fighter_level_5 = player_characters(:thorin) # level 5
    fighter_level_5.current_hit_points = 10

    feature = class_features(:fighter_second_wind)
    action = Combat::CombatAction.new(
      source_type: :class_feature,
      source_id:   feature.id,
      actor:       fighter_level_5,
      targets:     []
    )

    results = Combat::ActionRunner.call(action: action)

    assert_equal 1, results.size
    outcome = results.first.roll_outcome

    assert_equal 5, outcome.modifiers["actor_level"]
    assert outcome.total >= 6 # min 1d10(1) + level(5)
  end

  test "raises when source_type is unsupported" do
    action = Combat::CombatAction.new(
      source_type: :spell,
      source_id:   0,
      actor:       @fighter
    )

    assert_raises(ArgumentError) do
      Combat::ActionRunner.call(action: action)
    end
  end

  test "raises when class feature has no effect_payload" do
    feature = class_features(:fighter_action_surge) # no effect_payload

    action = Combat::CombatAction.new(
      source_type: :class_feature,
      source_id:   feature.id,
      actor:       @fighter
    )

    assert_raises(RuntimeError) do
      Combat::ActionRunner.call(action: action)
    end
  end

  test "PlayerCharacter#use_class_feature delegates to ActionRunner" do
    Random.srand(1)
    @fighter.current_hit_points = 3

    results = @fighter.use_class_feature(slug: "second-wind")

    assert_equal 1, results.size
    assert_equal :heal, results.first.kind
    assert results.first.hp_after > 3
  end
end
