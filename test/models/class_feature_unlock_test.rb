require "test_helper"

class ClassFeatureUnlockTest < ActiveSupport::TestCase
  setup do
    @feature = class_features(:fighter_action_surge)
  end

  test "valid unlock" do
    unlock = ClassFeatureUnlock.new(
      class_feature: @feature,
      level: 9,
      uses: 1,
      description: "Still one use at this level."
    )

    assert unlock.valid?
  end

  test "invalid level outside 1..20" do
    [ 0, 21, -3 ].each do |bad_level|
      unlock = ClassFeatureUnlock.new(class_feature: @feature, level: bad_level)
      assert_not unlock.valid?, "Expected level #{bad_level} to be invalid"
    end
  end

  test "level unique per class feature" do
    duplicate = ClassFeatureUnlock.new(
      class_feature: @feature,
      level: class_feature_unlocks(:action_surge_level_2).level
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:level], "has already been taken"
  end

  test "uses cannot be negative" do
    unlock = ClassFeatureUnlock.new(class_feature: @feature, level: 4, uses: -1)

    assert_not unlock.valid?
    assert_includes unlock.errors[:uses], "must be greater than or equal to 0"
  end

  test "an effect payload must be of a known kind and carry its kind's fields, with the values it accepts" do
    error_for = ->(payload) { ClassFeatureUnlock.new(class_feature: @feature, level: 4, effect_payload: payload).tap(&:valid?).errors[:effect_payload] }
    war_magic = { kind: "grants_activity", activity: "weapon_attack", count: 1, as: "bonus_action", after: { cast_with_action: "cantrip" } }

    assert_empty error_for.(war_magic)
    assert_empty error_for.({ kind: "extra_action" })
    assert_equal [ "has an unknown kind: \"teleport\"" ], error_for.({ kind: "teleport" })
    assert_equal [ "has an unknown kind: nil" ], error_for.({ roll: "1d6" })
    assert_equal [ "is missing against" ], error_for.({ kind: "rider", event: "weapon_hit", applies: "disadvantage_on_next_save" })
    assert_equal [ "is missing after.cast_with_action" ], error_for.(war_magic.merge(after: {}))
    assert_equal [ "after.cast_with_action must be one of cantrip, any_spell" ], error_for.(war_magic.merge(after: { cast_with_action: "ritual" }))
    assert_equal [ "as must be one of action, bonus_action, reaction" ], error_for.(war_magic.merge(as: "free"))
    assert_equal [ "count must be an integer of at least 1" ], error_for.(war_magic.merge(count: "1"))
    assert_equal [ "count must be an integer of at least 1" ], error_for.(war_magic.merge(count: 0)), "a grant of no activity grants nothing"
    assert_equal [ "after must be an object" ], error_for.(war_magic.merge(after: "cantrip"))
    assert_equal [ "has an unknown field trigger" ], error_for.({ kind: "extra_action", trigger: "always" }), "a kind of its own is never a passive"
    assert_equal [ "is missing roll" ], error_for.({ kind: "heal", target: "self" })
  end

  test "a maneuver's statuses are a list of objects with exactly a kind and an end from Combat::Status's vocabulary" do
    error_for = ->(payload) { ClassFeatureUnlock.new(class_feature: @feature, level: 4, effect_payload: payload).tap(&:valid?).errors[:effect_payload] }
    maneuver = { kind: "damage", roll: "1d8", target: "enemy", applies_to: "weapon_attack" }
    mark = { kind: "next_attack_advantage", ends: "source_turn_start" }

    assert_empty error_for.(maneuver.merge(statuses: [ mark ]))
    assert_empty error_for.(maneuver.merge(statuses: []))
    assert_equal [ "has an unknown field debuff" ], error_for.(maneuver.merge(debuff: "next_attack_advantage")), "debuff left the vocabulary"
    assert_equal [ "statuses must be a list" ], error_for.(maneuver.merge(statuses: mark))
    assert_equal [ "statuses[0] must be an object" ], error_for.(maneuver.merge(statuses: [ "next_attack_advantage" ]))
    assert_equal [ "statuses[1].kind must be one of #{Combat::Status::KINDS.join(', ')}" ], error_for.(maneuver.merge(statuses: [ mark, mark.merge(kind: "stunned") ]))
    assert_equal [ "statuses[0].ends must be one of source_turn_start" ], error_for.(maneuver.merge(statuses: [ mark.merge(ends: "end_of_round") ]))
    assert_equal [ "is missing statuses[0].ends" ], error_for.(maneuver.merge(statuses: [ mark.except(:ends) ]))
    assert_equal [ "has an unknown field statuses[0].rounds" ], error_for.(maneuver.merge(statuses: [ mark.merge(rounds: 1) ]))
    [ "stunned", "next_attack_advantage" ].each do |status|
      assert_equal [ "applies must be one of disadvantage_on_next_save" ],
        error_for.({ kind: "rider", event: "weapon_hit", applies: status, against: "own_spells" }), "a rider applies only what the engine runs on a hit"
    end
  end

  test "a save is exactly an ability, a dc from 1 to 30 or spell, and an on_success of half or negate" do
    error_for = ->(payload) { ClassFeatureUnlock.new(class_feature: @feature, level: 4, effect_payload: payload).tap(&:valid?).errors[:effect_payload] }
    save = { ability: "dexterity", dc: 15, on_success: "half" }
    with_save = ->(changes) { { kind: "damage", roll: "1d6", target: "enemy", save: save.merge(changes) } }

    assert_empty error_for.(with_save.({}))
    assert_empty error_for.(with_save.(dc: "spell", on_success: "negate"))
    assert_empty error_for.({ kind: "heal", roll: "1d6", target: "ally", save: save.merge(dc: 30) })
    assert_equal [ "is missing save.ability" ], error_for.(with_save.({}).merge(save: save.except(:ability)))
    assert_equal [ "is missing save.dc" ], error_for.(with_save.({}).merge(save: save.except(:dc)))
    assert_equal [ "is missing save.on_success" ], error_for.(with_save.({}).merge(save: save.except(:on_success)))
    assert_equal [ "save.ability must be one of #{AbilityScores::ABILITY_SCORE_COLUMNS.join(', ')}" ], error_for.(with_save.(ability: "dex"))
    [ 0, 31, "10", "Spell", 10.5 ].each do |dc|
      assert_equal [ "save.dc must be an integer from 1 to 30 or spell" ], error_for.(with_save.(dc:)), "dc #{dc.inspect}"
    end
    assert_equal [ "save.on_success must be one of half, negate" ], error_for.(with_save.(on_success: "halff")), "a typo would deal full damage"
    assert_equal [ "save must be an object" ], error_for.(with_save.({}).merge(save: "dexterity"))
  end

  test "every fixture and seed unlock fits the effect vocabulary" do
    SeedData.load_all

    assert_empty ClassFeatureUnlock.includes(:class_feature).reject(&:valid?).map { |unlock| "#{unlock.class_feature.slug} #{unlock.level}: #{unlock.errors.full_messages}" }
  end
end
