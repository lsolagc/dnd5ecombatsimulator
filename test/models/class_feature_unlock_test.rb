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
end
