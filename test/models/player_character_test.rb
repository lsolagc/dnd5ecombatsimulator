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
    character = PlayerCharacter.create!(name: "Champion 15", level: 15, player_class: fighter,
                                         martial_archetype: class_features(:fighter_champion_archetype))

    assert_equal 18, character.critical_hit_threshold
  end

  test "passive_effect_payloads returns only turn_start passives for current level" do
    fighter = player_classes(:fighter)
    character = PlayerCharacter.create!(name: "Champion 18 Passive List", level: 18, player_class: fighter,
                                         martial_archetype: class_features(:fighter_champion_archetype))

    payloads = character.passive_effect_payloads(trigger: "turn_start")

    assert_equal 1, payloads.size
    assert_equal "champion-survivor", payloads.first["feature_slug"]
    assert_equal "turn_start", payloads.first["trigger"]
  end

  test "passive_effect_payloads returns always-on modifier payloads" do
    fighter = player_classes(:fighter)
    character = PlayerCharacter.create!(name: "Champion 15 Passive Mod", level: 15, player_class: fighter,
                                         martial_archetype: class_features(:fighter_champion_archetype))

    payloads = character.passive_effect_payloads(trigger: "always")
    modifiers = payloads.select { |payload| payload["kind"] == "modifier" }

    assert modifiers.any? { |payload| payload["value"] == 19 }
    assert modifiers.any? { |payload| payload["value"] == 18 }
  end

  test "apply_start_of_turn_passives! heals with Survivor when eligible" do
    fighter = player_classes(:fighter)
    character = PlayerCharacter.create!(name: "Champion 18", level: 18, player_class: fighter,
                                         martial_archetype: class_features(:fighter_champion_archetype))

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

  test "setup_hit_points gives full HP for the level (max hit die + CON modifier at every level) when no override is given" do
    fighter = player_classes(:fighter) # d10
    character = PlayerCharacter.create!(
      name: "Full HP", level: 4, player_class: fighter,
      combatant_attributes: { constitution: 14 } # +2
    )

    assert_equal 4 * (10 + 2), character.reload.max_hit_points
  end

  # spell save DC / spell attack

  test "an Eldritch Knight's spell save DC and spell attack bonus use Intelligence and proficiency" do
    character = PlayerCharacter.create!(
      name: "EK Casting", level: 5, player_class: player_classes(:fighter),
      martial_archetype: class_features(:fighter_eldritch_knight_archetype),
      combatant_attributes: { intelligence: 16 } # +3, proficiency +3 at level 5
    )

    assert_equal 14, character.spell_save_dc # 8 + 3 + 3
    assert_equal 6, character.spell_attack_bonus # 3 + 3
  end

  test "spell save DC and spell attack bonus raise for a character with no spellcasting ability" do
    champion = player_characters(:champion_seven)

    assert_raises(RuntimeError) { champion.spell_save_dc }
    assert_raises(RuntimeError) { champion.spell_attack_bonus }
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

  # basic attack configuration

  test "roll_an_attack applies the combatant's configured attack_bonus as the to-hit modifier" do
    character = player_characters(:aragorn)
    character.combatant.update!(attack_bonus: 100)

    attack_roll = character.roll_an_attack

    assert attack_roll.total >= 101
  end

  test "roll_an_attack defaults the to-hit modifier to zero when attack_bonus is not configured" do
    character = player_characters(:aragorn)

    attack_roll = character.roll_an_attack

    assert attack_roll.total <= 20
  end

  test "armor_class includes the +1 bonus from Fighting Style: Defense" do
    character = player_characters(:fighter_defender)

    assert_equal character.combatant.armor_class + 1, character.armor_class
  end

  test "armor_class has no bonus without a chosen fighting style" do
    character = player_characters(:aragorn)

    assert_equal character.combatant.armor_class, character.armor_class
  end

  test "roll_an_attack applies the +2 to-hit bonus from Fighting Style: Archery" do
    archer = player_characters(:fighter_archer)
    no_style = player_characters(:aragorn)

    Random.srand(42) # to-hit natural: 7 (no crit)
    archer_total = archer.roll_an_attack.total

    Random.srand(42) # same natural roll again, so Archery's bonus is the only difference
    no_style_total = no_style.roll_an_attack.total

    assert_equal no_style_total + 2, archer_total
  end

  test "roll_an_attack applies the +2 damage bonus from Fighting Style: Dueling" do
    duelist = player_characters(:fighter_duelist)
    duelist.combatant.update!(damage_dice: "1d1")
    no_style = player_characters(:aragorn)
    no_style.combatant.update!(damage_dice: "1d1")

    Random.srand(42) # to-hit natural: 7 (no crit), so damage isn't doubled
    duelist_damage = duelist.roll_an_attack.damage

    Random.srand(42) # same rolls again, so Dueling's bonus is the only difference
    no_style_damage = no_style.roll_an_attack.damage

    assert_equal no_style_damage + 2, duelist_damage
  end

  test "damage_roll returns the combatant's configured damage_dice" do
    character = player_characters(:aragorn)
    character.combatant.update!(damage_dice: "1d8+3")

    assert_equal "1d8+3", character.damage_roll
  end

  test "damage_roll defaults to 1d4 when damage_dice is not configured" do
    character = player_characters(:aragorn)

    assert_equal "1d4", character.damage_roll
  end

  test "get_attacked applies the combatant's configured damage_type on a hit" do
    character = player_characters(:aragorn)
    character.combatant.update!(damage_type: "piercing")
    character.combatant.immunities["damage_types"]["piercing"] = true
    character.current_hit_points = character.max_hit_points
    attack_roll = Struct.new(:natural, :total, :damage).new(10, 999, 10)

    character.get_attacked(attack_roll: attack_roll)

    assert_equal character.max_hit_points, character.current_hit_points, "expected the configured piercing immunity to block all damage"
  end

  test "get_attacked defaults to bludgeoning damage_type when not configured" do
    character = player_characters(:aragorn)
    character.combatant.vulnerabilities["damage_types"]["bludgeoning"] = true
    character.current_hit_points = character.max_hit_points
    attack_roll = Struct.new(:natural, :total, :damage).new(10, 999, 3)

    character.get_attacked(attack_roll: attack_roll)

    assert_equal character.max_hit_points - 6, character.current_hit_points, "expected the default bludgeoning type to trigger vulnerability (double damage)"
  end

  test "get_attacked always hits on a natural 20, even when the total is below the armor class" do
    character = player_characters(:aragorn)
    character.current_hit_points = character.max_hit_points
    attack_roll = Struct.new(:natural, :total, :damage).new(20, 1, 4)

    result = character.get_attacked(attack_roll: attack_roll)

    assert result[:success]
    assert_equal character.max_hit_points - 4, character.current_hit_points
  end

  test "get_attacked always misses on a natural 1, even when the total beats the armor class" do
    character = player_characters(:aragorn)
    character.current_hit_points = character.max_hit_points
    attack_roll = Struct.new(:natural, :total, :damage).new(1, 999, 4)

    result = character.get_attacked(attack_roll: attack_roll)

    assert_not result[:success]
    assert_equal character.max_hit_points, character.current_hit_points
  end

  # Spellcasting

  test "spellcasting_feature returns the class feature that grants spellcasting" do
    merlin = player_characters(:merlin)
    assert_equal "spellcasting", merlin.spellcasting_feature.slug
  end

  test "spellcasting_feature is nil for a class with no spellcasting-granting feature" do
    aragorn = player_characters(:aragorn)
    assert_nil aragorn.spellcasting_feature
  end

  test "available_spell_slots reads from the matching SpellSlotProgression" do
    merlin = player_characters(:merlin)
    assert_equal({ 1 => 2, 2 => 0, 3 => 0, 4 => 0 }, merlin.available_spell_slots)
  end

  test "available_spell_slots is empty when the character has no spellcasting feature" do
    aragorn = player_characters(:aragorn)
    assert_equal({}, aragorn.available_spell_slots)
  end
end
