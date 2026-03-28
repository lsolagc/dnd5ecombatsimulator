require "test_helper"

class ClassLevelProgressionTest < ActiveSupport::TestCase
  setup do
    @fighter = player_classes(:fighter)
    @cleric = player_classes(:cleric)
  end

  test "valid progression record" do
    progression = ClassLevelProgression.new(
      player_class: @fighter,
      level: 10,
      proficiency_bonus: 4,
      grants_ability_score_improvement: false,
      attacks_per_action: 2
    )
    assert progression.valid?
  end

  test "invalid without level" do
    progression = ClassLevelProgression.new(
      player_class: @fighter,
      proficiency_bonus: 2
    )
    assert_not progression.valid?
    assert_includes progression.errors[:level], "can't be blank"
  end

  test "invalid with level outside 1..20" do
    [ 0, 21, -1 ].each do |bad_level|
      progression = ClassLevelProgression.new(
        player_class: @fighter,
        level: bad_level,
        proficiency_bonus: 2
      )
      assert_not progression.valid?, "Expected level #{bad_level} to be invalid"
    end
  end

  test "invalid without proficiency_bonus" do
    progression = ClassLevelProgression.new(
      player_class: @fighter,
      level: 3
    )
    assert_not progression.valid?
    assert_includes progression.errors[:proficiency_bonus], "can't be blank"
  end

  test "invalid when attacks_per_action is less than 1" do
    progression = ClassLevelProgression.new(
      player_class: @fighter,
      level: 3,
      proficiency_bonus: 2,
      attacks_per_action: 0
    )

    assert_not progression.valid?
    assert_includes progression.errors[:attacks_per_action], "must be greater than or equal to 1"
  end

  test "level must be unique per player class" do
    ClassLevelProgression.create!(
      player_class: @fighter,
      level: 1,
      proficiency_bonus: 2,
      grants_ability_score_improvement: false
    )

    duplicate = ClassLevelProgression.new(
      player_class: @fighter,
      level: 1,
      proficiency_bonus: 2
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:level], "has already been taken"
  end

  test "same level allowed for different classes" do
    ClassLevelProgression.create!(
      player_class: @fighter,
      level: 1,
      proficiency_bonus: 2,
      grants_ability_score_improvement: false
    )

    progression = ClassLevelProgression.new(
      player_class: @cleric,
      level: 1,
      proficiency_bonus: 2,
      grants_ability_score_improvement: false
    )
    assert progression.valid?
  end

  test "loaded records are frozen" do
    progression = ClassLevelProgression.create!(
      player_class: @fighter,
      level: 2,
      proficiency_bonus: 2,
      grants_ability_score_improvement: false
    )

    loaded = ClassLevelProgression.find(progression.id)
    assert_predicate loaded, :frozen?
  end

  test "new records are not frozen" do
    progression = ClassLevelProgression.new
    assert_not_predicate progression, :frozen?
  end
end
