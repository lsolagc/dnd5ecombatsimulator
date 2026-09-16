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
    fighter = player_characters(:fighter_indomitable_nine) # constitution: 12 (mod +1)
    fighter.current_hit_points = fighter.max_hit_points
    attacker = player_characters(:barbarian_test_striker)

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

  test "PlayerCharacter#use_class_feature delegates to ActionRunner" do
    Random.srand(1)
    @fighter.current_hit_points = 3

    results = @fighter.use_class_feature(slug: "second-wind")

    assert_equal 1, results.size
    assert_equal :heal, results.first.kind
    assert results.first.hp_after > 3
  end

  test "PlayerCharacter#cast_spell delegates to ActionRunner and consumes a spell slot" do
    merlin = player_characters(:merlin) # level 1 wizard, 2 level-1 slots
    target = player_characters(:aragorn)
    target.current_hit_points = 10

    assert_equal 2, merlin.available_spell_slots[1]

    results = merlin.cast_spell(slug: "magic-missile", targets: [ target ])

    assert_equal 1, results.size
    assert_equal :damage, results.first.kind
    assert_equal 1, merlin.available_spell_slots[1]
  end

  test "cast_spell does not consume a slot for cantrips" do
    merlin = player_characters(:merlin)
    target = player_characters(:aragorn)
    target.current_hit_points = 10
    slots_before = merlin.available_spell_slots.dup

    merlin.cast_spell(slug: "fire-bolt", targets: [ target ])

    assert_equal slots_before, merlin.available_spell_slots
  end

  test "cast_spell raises when no spell slots remain for that level" do
    merlin = player_characters(:merlin)
    merlin.available_spell_slots = { 1 => 0 }

    assert_raises(RuntimeError) do
      merlin.cast_spell(slug: "magic-missile", targets: [ player_characters(:aragorn) ])
    end
  end

  test "cast_spell raises when the spell has no effect_payload" do
    merlin = player_characters(:merlin)

    assert_raises(RuntimeError) do
      merlin.cast_spell(slug: "shield")
    end
  end
end
