require "test_helper"

class Combat::ParticipantTest < ActiveSupport::TestCase
  setup do
    @aragorn = player_characters(:aragorn) # level 1 fighter, max_hit_points: 12
  end

  test "starts at the sheet's maximum HP, or at the HP it is given" do
    assert_equal 12, Combat::Participant.new(@aragorn).current_hit_points
    assert_equal 5, Combat::Participant.new(@aragorn, hit_points: 5).current_hit_points
  end

  test "damage lowers HP down to 0, where it is dead" do
    fighter = Combat::Participant.new(@aragorn, hit_points: 5)

    fighter.take_damage(amount: 3, damage_type: "slashing")
    assert_equal 2, fighter.current_hit_points
    assert_not fighter.dead?

    fighter.take_damage(amount: 10, damage_type: "slashing")
    assert_equal 0, fighter.current_hit_points
    assert fighter.dead?
    assert_raises(ArgumentError) { fighter.take_damage(amount: 0, damage_type: "slashing") }
  end

  test "damage follows the sheet's defenses: immunity takes none, resistance halves, vulnerability doubles" do
    defenses = { "immunities" => "poison", "resistances" => "fire", "vulnerabilities" => "cold" }
    defenses.each { |column, type| @aragorn.combatant.public_send(column)["damage_types"][type] = true }

    { "poison" => 12, "fire" => 10, "cold" => 2 }.each do |type, hit_points_after|
      fighter = Combat::Participant.new(@aragorn)
      fighter.take_damage(amount: 5, damage_type: type)
      assert_equal hit_points_after, fighter.current_hit_points, type
    end
  end

  test "healing never goes past the maximum" do
    fighter = Combat::Participant.new(@aragorn, hit_points: 5)

    assert_equal 9, fighter.heal(4)
    assert_equal 12, fighter.heal(10)
  end

  test "cast_spell spends a slot of the spell's level, none for a cantrip, and the sheet keeps its own" do
    merlin = player_characters(:merlin) # level 1 wizard, 2 level-1 slots
    wizard = Combat::Participant.new(merlin)
    target = Combat::Participant.new(@aragorn)

    results = wizard.cast_spell(spells(:magic_missile), targets: [ target ])
    assert_equal [ :damage ], results.map(&:kind)
    assert_equal 1, wizard.available_spell_slots[1]

    wizard.cast_spell(spells(:fire_bolt), targets: [ target ])
    assert_equal 1, wizard.available_spell_slots[1]

    assert_equal 2, merlin.spell_slots[1]
  end

  test "cast_spell raises when no slot of the spell's level is left" do
    wizard = Combat::Participant.new(player_characters(:merlin))
    2.times { wizard.cast_spell(spells(:magic_missile), targets: [ Combat::Participant.new(@aragorn) ]) }

    assert_raises(RuntimeError) { wizard.cast_spell(spells(:magic_missile), targets: [ Combat::Participant.new(@aragorn) ]) }
  end

  test "uses start from the feature book, go down one per use to 0, and unlimited features have none" do
    fighter = Combat::Participant.new(player_characters(:thorin)) # level 5: one Action Surge
    action_surge = class_features(:fighter_action_surge).id

    assert_equal fighter.feature_book.initial_uses, fighter.feature_book.unlocks.to_h { |unlock| [ unlock.class_feature_id, fighter.uses_left(unlock.class_feature_id) ] }.compact
    assert_equal 1, fighter.uses_left(action_surge)

    fighter.spend_use!(action_surge)
    assert_equal 0, fighter.uses_left(action_surge)
    fighter.spend_use!(action_surge)
    assert_equal 0, fighter.uses_left(action_surge)

    assert_nil fighter.uses_left(class_features(:fighter_champion_improved_critical).id)
  end

  test "Survivor heals at the start of the turn at half HP or below, and not above it" do
    champion = PlayerCharacter.create!(name: "Champion 18", level: 18, player_class: player_classes(:fighter),
                                       martial_archetype: class_features(:fighter_champion_archetype))
    half = champion.max_hit_points / 2

    hurt = Combat::Participant.new(champion, hit_points: half)
    results = hurt.apply_turn_passives!(trigger: "turn_start")
    assert_equal [ [ :heal, 5 ] ], results.map { |result| [ result.kind, result.amount ] }
    assert_equal half + 5, hurt.current_hit_points

    assert_empty Combat::Participant.new(champion, hit_points: half + 1).apply_turn_passives!(trigger: "turn_start")
    assert_empty Combat::Participant.new(champion, hit_points: half).apply_turn_passives!(trigger: "turn_end")
  end

  test "reads everything else from the sheet" do
    thorin = player_characters(:thorin)
    fighter = Combat::Participant.new(thorin)

    %i[id name level max_hit_points initiative armor_class damage_dice damage_type attacks_per_action weapon_attack_bonus
       weapon_damage_modifier critical_hit_threshold proficiency_bonus strength_modifier
       dexterity_modifier constitution_modifier intelligence_modifier wisdom_modifier charisma_modifier].each do |reading|
      assert_equal thorin.public_send(reading), fighter.public_send(reading), reading
    end
    assert_equal thorin.spells.to_a, fighter.spells.to_a
    merlin = player_characters(:merlin)
    assert_equal [ merlin.spellcasting_feature, merlin.spell_save_dc, merlin.spell_attack_bonus ],
                 Combat::Participant.new(merlin).then { |wizard| [ wizard.spellcasting_feature, wizard.spell_save_dc, wizard.spell_attack_bonus ] }
    assert_equal thorin.passive_effect_payloads(trigger: "always"), fighter.passive_effect_payloads(trigger: "always")
  end
end
