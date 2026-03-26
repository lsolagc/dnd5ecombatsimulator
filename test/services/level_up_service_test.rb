require "test_helper"

class LevelUpServiceTest < ActiveSupport::TestCase
  setup do
    fighter = player_classes(:fighter)

    [
      { level: 2, proficiency_bonus: 2, grants_ability_score_improvement: false },
      { level: 4, proficiency_bonus: 2, grants_ability_score_improvement: true },
      { level: 6, proficiency_bonus: 3, grants_ability_score_improvement: true }
    ].each do |attrs|
      ClassLevelProgression.find_or_create_by!(player_class: fighter, level: attrs[:level]) do |progression|
        progression.proficiency_bonus = attrs[:proficiency_bonus]
        progression.grants_ability_score_improvement = attrs[:grants_ability_score_improvement]
      end
    end
  end

  test "increments character level" do
    character = player_characters(:aragorn) # level 1 fighter
    original_level = character.level
    LevelUpService.new(player_character: character).call
    assert_equal original_level + 1, character.reload.level
  end

  test "returns a result with the new level" do
    character = player_characters(:aragorn)
    result = LevelUpService.new(player_character: character).call
    assert_equal 2, result.new_level
  end

  test "returns the correct proficiency_bonus in result" do
    character = player_characters(:aragorn) # levels 1→2, still +2
    result = LevelUpService.new(player_character: character).call
    assert_equal 2, result.proficiency_bonus
  end

  test "syncs combatant proficiency_bonus" do
    character = player_characters(:thorin) # level 5→6, still +3
    LevelUpService.new(player_character: character).call
    assert_equal 3, character.combatant.reload.proficiency_bonus
  end

  test "reports can_improve_ability_scores? correctly at an ASI level" do
    # Level up aragorn from 1 to 2 three times to reach level 4 (Fighter ASI)
    character = player_characters(:aragorn)
    character.update!(level: 3)
    result = LevelUpService.new(player_character: character).call
    assert_equal 4, result.new_level
    assert result.can_improve_ability_scores
  end

  test "reports can_improve_ability_scores? false at a non-ASI level" do
    character = player_characters(:aragorn) # 1→2, no ASI
    result = LevelUpService.new(player_character: character).call
    assert_not result.can_improve_ability_scores
  end
end
