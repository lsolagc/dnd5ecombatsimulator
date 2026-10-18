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

  test "every fixture and seed unlock fits the effect vocabulary" do
    SeedData.load_all

    assert_empty ClassFeatureUnlock.includes(:class_feature).reject(&:valid?).map { |unlock| "#{unlock.class_feature.slug} #{unlock.level}: #{unlock.errors.full_messages}" }
  end
end
