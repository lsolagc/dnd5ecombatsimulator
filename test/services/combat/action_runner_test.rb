require "test_helper"

class Combat::ActionRunnerTest < ActiveSupport::TestCase
  setup do
    @fighter = Combat::Participant.new(player_characters(:aragorn), hit_points: 4) # level 1 fighter, max_hit_points: 12; damage taken
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
    fighter_level_5 = Combat::Participant.new(player_characters(:thorin), hit_points: 10) # level 5

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
      source_type: :weapon_attack,
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

  test "reroll_saving_throw reflects the second saving throw when the first fails" do
    feature = class_features(:barbarian_test_save_strike) # test fixture, see class_features.yml
    fighter = Combat::Participant.new(player_characters(:fighter_indomitable_nine)) # constitution: 12 (mod +1)
    attacker = Combat::Participant.new(player_characters(:barbarian_test_striker))

    action = Combat::CombatAction.new(
      source_type: :class_feature,
      source_id:   feature.id,
      actor:       attacker,
      targets:     [ fighter ]
    )

    Random.srand(46) # 1d6 roll = 6; 1st constitution save total 7 (fails dc 8); reroll total 10 (succeeds)
    results = Combat::ActionRunner.call(action: action, reroll_saving_throw: true)

    assert_equal 1, results.size
    result = results.first

    assert result.saving_throw.rerolled
    assert_equal 3, result.amount # half of 6, since the reroll succeeded
  end

  test "a spell without an effect_payload raises" do
    action = Combat::CombatAction.new(source_type: :spell, source_id: spells(:shield).id, actor: Combat::Participant.new(player_characters(:merlin)))

    assert_raises(RuntimeError) { Combat::ActionRunner.call(action:) }
  end
end
