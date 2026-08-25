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

  # Champion subclass passives

  test "critical_hit_threshold is 20 when Champion critical features are not unlocked" do
    character = player_characters(:aragorn) # level 1 fighter
    assert_equal 20, character.critical_hit_threshold
  end

  test "critical_hit_threshold is 19 when Improved Critical is unlocked" do
    character = player_characters(:thorin) # level 5 fighter
    assert_equal 19, character.critical_hit_threshold
  end

  test "critical_hit_threshold is 18 when Superior Critical is unlocked" do
    fighter = player_classes(:fighter)
    character = PlayerCharacter.create!(name: "Champion 15", level: 15, player_class: fighter)

    assert_equal 18, character.critical_hit_threshold
  end

  test "passive_effect_payloads returns only turn_start passives for current level" do
    fighter = player_classes(:fighter)
    character = PlayerCharacter.create!(name: "Champion 18 Passive List", level: 18, player_class: fighter)

    payloads = character.passive_effect_payloads(trigger: "turn_start")

    assert_equal 1, payloads.size
    assert_equal "champion-survivor", payloads.first["feature_slug"]
    assert_equal "turn_start", payloads.first["trigger"]
  end

  test "passive_effect_payloads returns always-on modifier payloads" do
    fighter = player_classes(:fighter)
    character = PlayerCharacter.create!(name: "Champion 15 Passive Mod", level: 15, player_class: fighter)

    payloads = character.passive_effect_payloads(trigger: "always")
    modifiers = payloads.select { |payload| payload["kind"] == "modifier" }

    assert modifiers.any? { |payload| payload["value"] == 19 }
    assert modifiers.any? { |payload| payload["value"] == 18 }
  end

  test "apply_start_of_turn_passives! heals with Survivor when eligible" do
    fighter = player_classes(:fighter)
    character = PlayerCharacter.create!(name: "Champion 18", level: 18, player_class: fighter)

    character.current_hit_points = [ (character.max_hit_points / 2), 1 ].max
    results = character.apply_start_of_turn_passives!

    assert_equal 1, results.size
    assert_equal :heal, results.first.kind
    assert_equal 5, results.first.amount
    assert_equal [ character.max_hit_points, (character.max_hit_points / 2) + 5 ].min, character.current_hit_points
  end

  test "apply_start_of_turn_passives! does not heal with Survivor above half HP" do
    fighter = player_classes(:fighter)
    character = PlayerCharacter.create!(name: "Champion 18 No Heal", level: 18, player_class: fighter)

    character.current_hit_points = (character.max_hit_points / 2) + 1
    results = character.apply_start_of_turn_passives!

    assert_empty results
  end

  # max_hit_points_input override

  test "setup_hit_points uses the override instead of the automatic calculation when present" do
    fighter = player_classes(:fighter)
    character = PlayerCharacter.create!(name: "HP Override", level: 5, player_class: fighter, max_hit_points_input: 999)

    assert_equal 999, character.reload.max_hit_points
  end

  test "setup_hit_points falls back to the automatic calculation when the override is blank" do
    fighter = player_classes(:fighter)
    character = PlayerCharacter.create!(name: "HP Auto", level: 1, player_class: fighter)

    assert_equal character.hit_points_at_level_one, character.reload.max_hit_points
  end

  test "updating max_hit_points_input persists the override on the associated combatant" do
    character = player_characters(:aragorn)

    character.update!(max_hit_points_input: 42)

    assert_equal 42, PlayerCharacter.includes(:combatant).find(character.id).max_hit_points
  end

  test "max_hit_points_input rejects zero, negative, non-integer, and values above the Postgres integer ceiling" do
    fighter = player_classes(:fighter)

    [ 0, -1, 1.5, PlayerCharacter::MAX_HIT_POINTS_INPUT_CEILING + 1 ].each do |bad_value|
      character = PlayerCharacter.new(name: "Bad HP", level: 1, player_class: fighter, max_hit_points_input: bad_value)
      assert_not character.valid?, "expected #{bad_value.inspect} to be invalid"
      assert_includes character.errors.attribute_names, :max_hit_points_input
    end
  end

  test "max_hit_points_input allows a blank value" do
    fighter = player_classes(:fighter)
    character = PlayerCharacter.new(name: "Blank HP", level: 1, player_class: fighter)

    assert character.valid?
  end
end
