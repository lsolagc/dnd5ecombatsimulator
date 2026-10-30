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

  test "a status is one per kind and source on its carrier: applied again by the same source, it renews" do
    carrier, source, other = [ :aragorn, :aragorn_copy, :merlin ].map { |name| Combat::Participant.new(player_characters(name)) }
    mark = ->(from, ends: "source_turn_start") { Combat::Status.new(kind: "next_attack_advantage", source: from, ends:) }

    carrier.add_status(mark.(source, ends: nil))
    carrier.add_status(mark.(source))
    carrier.add_status(mark.(other))
    carrier.add_status(Combat::Status.new(kind: "disadvantage_on_next_save", source:, ends: nil))

    assert_equal [ mark.(source), mark.(other) ], carrier.statuses.first(2), "the renewed one replaces the old, it does not stack"
    assert_equal 3, carrier.statuses.size, "another kind from the same source is its own status"
  end

  test "take_statuses removes and returns the kind's statuses, by anyone but not_from or only from" do
    carrier, source, other = [ :aragorn, :aragorn_copy, :merlin ].map { |name| Combat::Participant.new(player_characters(name)) }
    [ source, other ].each { |from| carrier.add_status(Combat::Status.new(kind: "next_attack_advantage", source: from, ends: nil)) }
    save = Combat::Status.new(kind: "disadvantage_on_next_save", source:, ends: nil)
    carrier.add_status(save)

    assert carrier.status?("next_attack_advantage", not_from: source)
    assert_not carrier.status?("disadvantage_on_next_save", from: other)
    assert_equal [ other ], carrier.take_statuses("next_attack_advantage", not_from: source).map(&:source)
    assert_not carrier.status?("next_attack_advantage", not_from: source)
    assert_equal [], carrier.take_statuses("disadvantage_on_next_save", from: other)
    assert_equal [ save ], carrier.take_statuses("disadvantage_on_next_save", from: source)
    assert_equal [ source ], carrier.statuses.map(&:source)
    assert_equal [], Combat::Participant.new(@aragorn).take_statuses("next_attack_advantage")
  end

  test "expire_statuses! removes only the source's statuses that end at the start of its turn" do
    carrier, source, other = [ :aragorn, :aragorn_copy, :merlin ].map { |name| Combat::Participant.new(player_characters(name)) }
    kept = [ Combat::Status.new(kind: "disadvantage_on_next_save", source:, ends: nil),
             Combat::Status.new(kind: "next_attack_advantage", source: other, ends: "source_turn_start") ]
    carrier.add_status(Combat::Status.new(kind: "next_attack_advantage", source:, ends: "source_turn_start"))
    kept.each { |status| carrier.add_status(status) }

    carrier.expire_statuses!(source:)

    assert_equal kept, carrier.statuses
  end

  test "action_options: an unlock without an effect inherits the one before it: the options, the resolver and the gambits all see it" do
    second_wind = class_features(:fighter_second_wind)
    ClassFeatureUnlock.create!(class_feature: second_wind, level: 10, uses: 2, description: "Test: one more use, same effect.")
    fighter = player_characters(:eldritch_knight_ten)
    participant = Combat::Participant.new(fighter)

    action = participant.action_options.find { |candidate| candidate.class_feature == second_wind }
    assert_equal [ "heal", 2 ], [ action&.payload&.dig("kind"), action&.uses_remaining ]

    effects = Combat::EffectResolver.call(action: Combat::CombatAction.new(source_type: :class_feature, source_id: second_wind.id, actor: participant))
    assert_equal [ "heal" ], effects.map(&:kind).map(&:to_s)

    assert_includes fighter.gambit_actions.map(&:action_choice), "class_feature:#{second_wind.id}"
    assert Gambit.new(owner: fighter, position: 1, target: :self, condition: :any, action_kind: :class_feature, class_feature: second_wind).valid?
  end

  test "action_options: a Battle Master who does not know Precision Attack does not see it" do
    battle_master = player_characters(:battle_master_seven)
    battle_master.player_character_maneuvers.destroy_all

    options = Combat::Participant.new(battle_master).action_options

    assert_nil options.find { |action| action.type == :class_feature && action.class_feature.slug == "battle-master-maneuver-precision-attack" }
  end

  test "action_options: a spell disappears once its spell slot is exhausted" do
    wizard = Combat::Participant.new(player_characters(:merlin))
    cast_slugs = -> { wizard.action_options.select(&:spell?).map { |action| action.spell.slug } }

    assert_includes cast_slugs.call, "magic-missile"
    assert_includes cast_slugs.call, "fire-bolt"

    wizard.available_spell_slots[1] = 0

    assert_not_includes cast_slugs.call, "magic-missile"
    assert_includes cast_slugs.call, "fire-bolt" # cantrips never consume a slot
  end
end
