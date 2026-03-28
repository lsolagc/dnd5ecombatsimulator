require "test_helper"

class PlayerCharacterTest < ActiveSupport::TestCase
  setup do
    fighter = player_classes(:fighter)

    [
      { level: 1, proficiency_bonus: 2, grants_ability_score_improvement: false, attacks_per_action: 1 },
      { level: 4, proficiency_bonus: 2, grants_ability_score_improvement: true, attacks_per_action: 1 },
      { level: 5, proficiency_bonus: 3, grants_ability_score_improvement: false, attacks_per_action: 2 },
      { level: 6, proficiency_bonus: 3, grants_ability_score_improvement: true, attacks_per_action: 2 }
    ].each do |attrs|
      ClassLevelProgression.find_or_create_by!(player_class: fighter, level: attrs[:level]) do |progression|
        progression.proficiency_bonus = attrs[:proficiency_bonus]
        progression.grants_ability_score_improvement = attrs[:grants_ability_score_improvement]
        progression.attacks_per_action = attrs[:attacks_per_action]
      end
    end
  end

  # proficiency_bonus

  test "proficiency_bonus falls back to 2 when no progression is defined" do
    character = player_characters(:merlin)
    assert_equal 2, character.proficiency_bonus
  end

  test "proficiency_bonus returns value from class progression" do
    character = player_characters(:thorin) # level 5 fighter
    assert_equal 3, character.proficiency_bonus
  end

  test "attacks_per_action falls back to 1 when no progression is defined" do
    character = player_characters(:merlin)
    assert_equal 1, character.attacks_per_action
  end

  test "attacks_per_action returns value from class progression" do
    character = player_characters(:thorin) # level 5 fighter
    assert_equal 2, character.attacks_per_action
  end

  # class_progression

  test "class_progression returns the correct ClassLevelProgression" do
    character = player_characters(:aragorn) # level 1 fighter
    progression = character.class_progression
    assert_not_nil progression
    assert_equal 1, progression.level
    assert_equal character.player_class, progression.player_class
  end

  test "class_progression returns nil when no record exists for the level" do
    character = player_characters(:merlin) # wizard, no progression seeded
    assert_nil character.class_progression
  end

  # can_improve_ability_scores?

  test "can_improve_ability_scores? is false at a non-ASI level" do
    character = player_characters(:aragorn)
    assert_not character.can_improve_ability_scores?
  end

  # level_up!

  test "level_up! increments the level by 1" do
    character = player_characters(:aragorn)
    original_level = character.level
    character.level_up!
    assert_equal original_level + 1, character.reload.level
  end
end
