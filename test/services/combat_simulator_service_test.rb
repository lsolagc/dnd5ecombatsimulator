require "test_helper"

class CombatSimulatorServiceTest < ActiveSupport::TestCase
  test "returns the expected contract shape" do
    party_one = [ fresh_character(:aragorn) ]
    party_two = [ fresh_character(:aragorn_copy) ]

    result = CombatSimulatorService.new(party_one:, party_two:, seed: 1234, max_rounds: 3).call

    assert_includes result.keys, :winning_party
    assert_includes result.keys, :total_rounds
    assert_includes result.keys, :round_log
    assert_includes result.keys, :draw
    assert_includes result.keys, :outcome
    assert result[:round_log].is_a?(Array)
    assert result[:total_rounds] <= 3
  end

  test "is deterministic when using the same seed" do
    result_one = CombatSimulatorService.new(
      party_one: [ fresh_character(:thorin) ],
      party_two: [ fresh_character(:aragorn), fresh_character(:aragorn_copy) ],
      seed: 77,
      max_rounds: 5
    ).call

    result_two = CombatSimulatorService.new(
      party_one: [ fresh_character(:thorin) ],
      party_two: [ fresh_character(:aragorn), fresh_character(:aragorn_copy) ],
      seed: 77,
      max_rounds: 5
    ).call

    assert_equal result_one, result_two
  end

  test "signals explicit draw on simultaneous elimination" do
    fallen_one = fresh_character(:aragorn)
    fallen_two = fresh_character(:aragorn_copy)
    fallen_one.current_hit_points = 0
    fallen_two.current_hit_points = 0

    result = CombatSimulatorService.new(
      party_one: [ fallen_one ],
      party_two: [ fallen_two ],
      seed: 1,
      max_rounds: 5
    ).call

    assert_equal true, result[:draw]
    assert_nil result[:winning_party]
    assert_equal :draw, result[:outcome]
    assert_equal 0, result[:total_rounds]
  end

  test "respects max_rounds stop condition" do
    result = CombatSimulatorService.new(
      party_one: [ fresh_character(:thorin) ],
      party_two: [ fresh_character(:aragorn) ],
      seed: 42,
      max_rounds: 1
    ).call

    assert_equal 1, result[:total_rounds]
  end

  test "Survivor heals a Champion at half HP or below at the start of their turn" do
    champion = fresh_character(:champion_eighteen)
    champion.current_hit_points = champion.max_hit_points / 2
    starting_hit_points = champion.current_hit_points

    result = CombatSimulatorService.new(
      party_one: [ champion ],
      party_two: [ fresh_character(:aragorn) ],
      seed: 99,
      max_rounds: 1
    ).call

    passive_entries = result[:round_log].flat_map { |round| round[:turns] }
      .select { |turn| turn[:actor_id] == champion.id && turn.dig(:action, :type) == :turn_passive && turn.dig(:action, :trigger) == "turn_start" }

    assert_equal 1, passive_entries.size
    assert_equal :heal, passive_entries.first[:results].first[:kind]
    assert_operator champion.current_hit_points, :>, starting_hit_points
  end

  test "Precision Attack maneuver consumes a superiority die, adds its roll to damage, and disappears once dice are spent" do
    battle_master = battle_master_with_known_maneuvers(:battle_master_seven)
    target = fresh_character(:aragorn)

    service = CombatSimulatorService.new(party_one: [ battle_master ], party_two: [ target ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    maneuver_action = precision_attack_action(service:, actor: battle_master)
    assert maneuver_action, "expected Precision Attack to be available to a Battle Master who knows it"
    assert_equal 4, maneuver_action[:uses_remaining]

    Random.srand(1) # 1d8 natural roll: 6
    turn = service.send(:execute_class_feature_action, actor: battle_master, chosen_action: maneuver_action, round_number: 1, turn_index: 1)

    damage_result = turn[:results].first
    assert_equal :damage, damage_result[:kind]
    assert_equal 6, damage_result[:amount]

    remaining_action = precision_attack_action(service:, actor: battle_master)
    assert_equal 3, remaining_action[:uses_remaining]

    combat_superiority_id = class_features(:fighter_battle_master_combat_superiority).id
    service.send(:instance_variable_get, :@uses_remaining)[battle_master.id][combat_superiority_id] = 0

    assert_nil precision_attack_action(service:, actor: battle_master)
  end

  test "a Battle Master who does not know Precision Attack does not see it as an available action" do
    battle_master = battle_master_with_known_maneuvers(:battle_master_seven)
    battle_master.player_character_maneuvers.destroy_all

    service = CombatSimulatorService.new(party_one: [ battle_master ], party_two: [ fresh_character(:aragorn) ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    assert_nil precision_attack_action(service:, actor: battle_master)
  end

  test "Action Surge grants an extra action on the same turn and respects the uses limit" do
    actor = fresh_character(:fighter_no_archetype_seven)
    service = CombatSimulatorService.new(party_one: [ actor ], party_two: [ fresh_character(:aragorn_copy) ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    # Second Wind is otherwise available at this level; disable it so the extra action
    # deterministically resolves to a plain attack (only remaining option).
    uses_remaining = service.send(:instance_variable_get, :@uses_remaining)
    uses_remaining[actor.id][class_features(:fighter_second_wind).id] = 0

    action_surge_id = class_features(:fighter_action_surge).id
    assert_equal 1, uses_remaining[actor.id][action_surge_id]

    Random.srand(1)
    extra_turn = service.send(:action_surge_turn, actor: actor, round_number: 1, turn_index: 1)

    assert extra_turn, "expected Action Surge to grant an extra action"
    assert_equal true, extra_turn[:extra]
    assert_equal :attack, extra_turn.dig(:action, :type)
    assert_equal 0, uses_remaining[actor.id][action_surge_id]

    assert_nil service.send(:action_surge_turn, actor: actor, round_number: 1, turn_index: 2)
  end

  test "Indomitable rerolls a failed saving throw against the fighter and consumes a use" do
    fighter = player_characters(:fighter_indomitable_nine) # constitution: 12 (mod +1)
    attacker = player_characters(:barbarian_test_striker)

    service = CombatSimulatorService.new(party_one: [ attacker ], party_two: [ fighter ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    chosen_action = service.send(:available_actions_for, actor: attacker).find do |action|
      action[:type] == :class_feature && action[:class_feature].slug == "test-save-strike"
    end
    assert chosen_action, "expected the test save-strike fixture to be available to the attacker"

    indomitable_id = class_features(:fighter_indomitable).id
    uses_remaining = service.send(:instance_variable_get, :@uses_remaining)
    assert_equal 1, uses_remaining[fighter.id][indomitable_id]

    Random.srand(46) # 1d6 roll = 6; 1st constitution save total 7 (fails dc 8); reroll total 10 (succeeds)
    turn = service.send(:execute_class_feature_action, actor: attacker, chosen_action: chosen_action, round_number: 1, turn_index: 1)

    damage_result = turn[:results].first
    assert_equal :damage, damage_result[:kind]
    assert_equal 3, damage_result[:amount] # half of 6, since the reroll succeeded

    assert_equal 0, uses_remaining[fighter.id][indomitable_id]
  end

  test "an Eldritch Knight autonomously casts a spell during a simulated round" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven)
    target = fresh_character(:aragorn)

    result = CombatSimulatorService.new(party_one: [ caster ], party_two: [ target ], seed: 2, max_rounds: 1).call

    cast_turn = result[:round_log].flat_map { |round| round[:turns] }
      .find { |turn| turn[:actor_id] == caster.id && turn.dig(:action, :type) == :cast_spell }

    assert cast_turn, "expected the Eldritch Knight to autonomously cast a spell"
    assert_equal "magic-missile", cast_turn.dig(:action, :spell_slug)
    assert_equal :damage, cast_turn[:results].first[:kind]
    assert_equal 12, cast_turn[:results].first[:amount]
  end

  test "choose_turn_action picks the physical branch when the coin flip favors it" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven)
    service = CombatSimulatorService.new(party_one: [ caster ], party_two: [ fresh_character(:aragorn) ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    available = service.send(:available_actions_for, actor: caster)
    chosen = service.send(:choose_turn_action, available:, actor: caster)

    assert_equal :attack, chosen[:type]
  end

  test "choose_turn_action picks the spell branch when the coin flip favors it" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven)
    service = CombatSimulatorService.new(party_one: [ caster ], party_two: [ fresh_character(:aragorn) ], seed: 3, max_rounds: 1)
    service.send(:initialize_state)

    available = service.send(:available_actions_for, actor: caster)
    chosen = service.send(:choose_turn_action, available:, actor: caster)

    assert_equal :cast_spell, chosen[:type]
    assert_equal "magic-missile", chosen[:spell].slug
  end

  test "choose_turn_action does not consume extra randomness for a non-spellcasting actor" do
    # Comparing only the chosen action is not a reliable regression guard: for some
    # seeds/list sizes, an extra @rng draw before the real sample still lands on the
    # same element by coincidence. Compare the RNG's internal state instead, which only
    # matches if the exact same sequence of draws happened.
    actor = fresh_character(:aragorn)
    plain_service = CombatSimulatorService.new(party_one: [ actor ], party_two: [ fresh_character(:aragorn_copy) ], seed: 5, max_rounds: 1)
    heuristic_service = CombatSimulatorService.new(party_one: [ actor ], party_two: [ fresh_character(:aragorn_copy) ], seed: 5, max_rounds: 1)

    available = plain_service.send(:available_actions_for, actor: actor)
    plain_rng = plain_service.send(:instance_variable_get, :@rng)
    heuristic_rng = heuristic_service.send(:instance_variable_get, :@rng)

    available.sample(random: plain_rng)
    heuristic_service.send(:choose_turn_action, available:, actor: actor)

    assert_equal Marshal.dump(plain_rng), Marshal.dump(heuristic_rng),
      "choose_turn_action must consume @rng identically to a single available.sample(random: @rng) call"
  end

  test "cast_spell action disappears from available_actions_for once its spell slot is exhausted" do
    wizard = spellcaster_with_known_spells(:merlin)
    service = CombatSimulatorService.new(party_one: [ wizard ], party_two: [ fresh_character(:aragorn) ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    cast_slugs = service.send(:available_actions_for, actor: wizard)
      .select { |action| action[:type] == :cast_spell }
      .map { |action| action[:spell].slug }
    assert_includes cast_slugs, "magic-missile"
    assert_includes cast_slugs, "fire-bolt"

    wizard.available_spell_slots[1] = 0

    remaining_cast_slugs = service.send(:available_actions_for, actor: wizard)
      .select { |action| action[:type] == :cast_spell }
      .map { |action| action[:spell].slug }
    assert_not_includes remaining_cast_slugs, "magic-missile"
    assert_includes remaining_cast_slugs, "fire-bolt" # cantrips never consume a slot
  end

  test "non integer uses values are floored" do
    service = CombatSimulatorService.new(
      party_one: [ fresh_character(:merlin) ],
      party_two: [ fresh_character(:aragorn_copy) ]
    )

    assert_equal 2, service.send(:normalize_uses_value, 2.9)
    assert_equal 0, service.send(:normalize_uses_value, 0.8)
  end

  test "War Magic grants a bonus weapon attack when the turn's normal action casts a cantrip" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven)
    service = CombatSimulatorService.new(party_one: [ caster ], party_two: [ fresh_character(:aragorn) ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    chosen_action = service.send(:available_actions_for, actor: caster).find do |action|
      action[:type] == :cast_spell && action[:spell].slug == "fire-bolt"
    end
    assert chosen_action, "expected fire-bolt (a cantrip) to be an available action"

    Random.srand(1)
    bonus_turn = service.send(:war_magic_turn, actor: caster, chosen_action:, round_number: 1, turn_index: 1)

    assert bonus_turn, "expected War Magic to grant a bonus weapon attack"
    assert_equal true, bonus_turn[:bonus]
    assert_equal :attack, bonus_turn.dig(:action, :type)
  end

  test "War Magic does not grant a bonus attack for a non-cantrip spell before Improved War Magic" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven)
    chosen_action = { type: :cast_spell, spell: spells(:magic_missile) }
    service = CombatSimulatorService.new(party_one: [ caster ], party_two: [ fresh_character(:aragorn) ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    assert_nil service.send(:war_magic_turn, actor: caster, chosen_action:, round_number: 1, turn_index: 1)
  end

  test "Improved War Magic grants a bonus weapon attack even for a non-cantrip spell" do
    caster = spellcaster_with_known_spells(:eldritch_knight_eighteen)
    service = CombatSimulatorService.new(party_one: [ caster ], party_two: [ fresh_character(:aragorn) ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    chosen_action = service.send(:available_actions_for, actor: caster).find do |action|
      action[:type] == :cast_spell && action[:spell].slug == "magic-missile"
    end
    assert chosen_action, "expected magic-missile to be an available action"

    Random.srand(1)
    bonus_turn = service.send(:war_magic_turn, actor: caster, chosen_action:, round_number: 1, turn_index: 1)

    assert bonus_turn, "expected Improved War Magic to grant a bonus weapon attack for a non-cantrip spell"
    assert_equal true, bonus_turn[:bonus]
    assert_equal :attack, bonus_turn.dig(:action, :type)
  end

  test "a successful weapon attack from an Eldritch Knight with Eldritch Strike marks the target as pending" do
    caster = spellcaster_with_known_spells(:eldritch_knight_ten)
    target = fresh_character(:aragorn)

    service = CombatSimulatorService.new(party_one: [ caster ], party_two: [ target ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    Random.srand(1)
    turn = service.send(:execute_attack_action, actor: caster, round_number: 1, turn_index: 1)

    assert_equal true, turn[:results].first[:success], "expected the attack to hit (attack_bonus is set high for determinism)"
    pending = service.send(:instance_variable_get, :@eldritch_strike_pending)
    assert_equal caster.id, pending[target.id]
  end

  test "Eldritch Strike imposes disadvantage on the target's next save against the same caster's spell, then stops" do
    caster = spellcaster_with_known_spells(:eldritch_knight_ten)
    target = fresh_character(:aragorn) # dexterity 12 (mod +1)

    service = CombatSimulatorService.new(party_one: [ caster ], party_two: [ target ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)
    service.send(:instance_variable_get, :@eldritch_strike_pending)[target.id] = caster.id

    chosen_action = service.send(:available_actions_for, actor: caster).find do |action|
      action[:type] == :cast_spell && action[:spell].slug == "test-save-spell"
    end
    assert chosen_action, "expected test-save-spell to be an available action"

    # seed 4: 1d6 damage roll = 3; disadvantage keeps the worse of two d20 saves
    # (+1 dexterity modifier) = total 7, failing DC 8 -> full damage (3).
    Random.srand(4)
    first_turn = service.send(:execute_cast_spell_action, actor: caster, chosen_action:, round_number: 1, turn_index: 1)
    assert_equal 3, first_turn[:results].first[:amount], "expected disadvantage to cause the save to fail (full damage)"

    pending = service.send(:instance_variable_get, :@eldritch_strike_pending)
    assert_nil pending[target.id], "expected the Eldritch Strike mark to be consumed by the first save"

    # Same seed, no pending mark this time: only one d20 is rolled (total 16), the save
    # succeeds against DC 8, halving the damage (3 / 2 = 1).
    Random.srand(4)
    second_turn = service.send(:execute_cast_spell_action, actor: caster, chosen_action:, round_number: 1, turn_index: 2)
    assert_equal 1, second_turn[:results].first[:amount], "expected the second save, without disadvantage, to succeed and halve damage"
  end

  test "Eldritch Strike's disadvantage does not leak to a different attacker or a different target" do
    marked_target = fresh_character(:aragorn) # dexterity 12 (mod +1)

    # A different attacker must not benefit from someone else's mark on the target.
    other_caster = spellcaster_with_known_spells(:eldritch_knight_eighteen)
    attacker_leak_service = CombatSimulatorService.new(party_one: [ other_caster ], party_two: [ marked_target ], seed: 1, max_rounds: 1)
    attacker_leak_service.send(:initialize_state)
    attacker_leak_service.send(:instance_variable_get, :@eldritch_strike_pending)[marked_target.id] = player_characters(:eldritch_knight_ten).id

    other_action = attacker_leak_service.send(:available_actions_for, actor: other_caster).find do |action|
      action[:type] == :cast_spell && action[:spell].slug == "test-save-spell"
    end
    assert other_action, "expected test-save-spell to be available to the other caster"

    # Same seed/roll math as the sibling test's "no disadvantage" branch: a single d20
    # save succeeds, halving damage -> a different attacker never gets the disadvantage.
    Random.srand(4)
    leaked_turn = attacker_leak_service.send(:execute_cast_spell_action, actor: other_caster, chosen_action: other_action, round_number: 1, turn_index: 1)
    assert_equal 1, leaked_turn[:results].first[:amount], "a different attacker must not receive the marked target's disadvantage"

    # The same attacker must not get disadvantage against a target they haven't marked.
    marker = spellcaster_with_known_spells(:eldritch_knight_ten)
    unmarked_target = fresh_character(:aragorn_copy)
    target_leak_service = CombatSimulatorService.new(party_one: [ marker ], party_two: [ unmarked_target ], seed: 1, max_rounds: 1)
    target_leak_service.send(:initialize_state)
    target_leak_service.send(:instance_variable_get, :@eldritch_strike_pending)[marked_target.id] = marker.id # a mark on someone else entirely

    marker_action = target_leak_service.send(:available_actions_for, actor: marker).find do |action|
      action[:type] == :cast_spell && action[:spell].slug == "test-save-spell"
    end
    assert marker_action, "expected test-save-spell to be available to the marking attacker"

    Random.srand(4)
    unmarked_turn = target_leak_service.send(:execute_cast_spell_action, actor: marker, chosen_action: marker_action, round_number: 1, turn_index: 1)
    assert_equal 1, unmarked_turn[:results].first[:amount], "the same attacker casting against an unmarked target must not get disadvantage"
  end

  test "war_magic_available? and eldritch_strike_unlocked? never consume @rng" do
    # Both are queried on every actor's turn/attack (not just Eldritch Knights), so any
    # accidental @rng draw here would desync every other seeded test in the suite.
    actor = fresh_character(:aragorn) # no spellcasting, no Eldritch Knight features
    service = CombatSimulatorService.new(party_one: [ actor ], party_two: [ fresh_character(:aragorn_copy) ], seed: 5, max_rounds: 1)
    service.send(:initialize_state)
    rng = service.send(:instance_variable_get, :@rng)

    before = Marshal.dump(rng)
    service.send(:war_magic_available?, actor: actor, chosen_action: { type: :attack })
    service.send(:eldritch_strike_unlocked?, actor: actor)
    after = Marshal.dump(rng)

    assert_equal before, after, "availability checks for War Magic/Eldritch Strike must never consume @rng"
  end

  test "serialized results carry the spell attack roll only when the effect made one" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven) # proficiency +2 (no progression), INT 10 (+0)
    target = player_characters(:aragorn)
    target.combatant.update!(armor_class: 100)
    target.current_hit_points = target.max_hit_points
    service = CombatSimulatorService.new(party_one: [ caster ], party_two: [ target ], seed: 1, max_rounds: 1)

    attack_effect = Combat::EffectInstance.new(kind: :damage, roll_expression: "1d10", target_type: "target", attack: "spell")
    plain_effect = Combat::EffectInstance.new(kind: :damage, roll_expression: "1d10", target_type: "target")
    Random.srand(2) # first d20 = 9: neither an auto-hit nor an auto-miss against AC 100
    results = [ attack_effect, plain_effect ].map { |effect| Combat::EffectExecutor.call(effect:, actor: caster, target:) }

    with_attack, without_attack = service.send(:serialize_effect_results, results:)

    assert_equal({ natural: with_attack.dig(:attack_roll, :natural), total: with_attack.dig(:attack_roll, :natural) + 2,
                   armor_class: 100, hit: false, crit: with_attack.dig(:attack_roll, :natural) == 20 }, with_attack[:attack_roll])
    assert_not_includes without_attack.keys, :attack_roll
  end

  test "a feature's target kind restricts who it may pick: enemy never self or allies, ally never enemies" do
    actor = fresh_character(:aragorn)
    ally = fresh_character(:aragorn_copy)
    enemies = [ fresh_character(:merlin), fresh_character(:elora) ]
    service = CombatSimulatorService.new(party_one: [ actor, ally ], party_two: enemies, seed: 1)

    picks = ->(target) { 50.times.map { service.send(:resolve_feature_target, actor:, payload: { "target" => target }) }.uniq }

    assert_empty picks.("enemy") - enemies
    assert_empty picks.("ally") - [ actor, ally ]
    assert_equal [ actor ], picks.("self")
    assert_raises(ArgumentError) { picks.("target") }
  end

  test "an enemy-targeted feature has no target once every enemy is down" do
    actor = fresh_character(:aragorn)
    downed = fresh_character(:merlin)
    downed.current_hit_points = 0
    service = CombatSimulatorService.new(party_one: [ actor ], party_two: [ downed ], seed: 1)

    assert_nil service.send(:resolve_feature_target, actor:, payload: { "target" => "enemy" })
  end

  private

    def fresh_character(fixture_name)
      character = player_characters(fixture_name).dup
      character.id = player_characters(fixture_name).id
      character.current_hit_points = character.max_hit_points
      character
    end

    # Uses the fixture record directly (no #dup): a has_many :through association like
    # #known_maneuvers only queries the database for a persisted owner, and .dup always
    # resets new_record? to true even after manually re-assigning the original id.
    def battle_master_with_known_maneuvers(fixture_name)
      character = player_characters(fixture_name)
      character.current_hit_points = character.max_hit_points
      character
    end

    # Uses the fixture record directly (no #dup), for the same reason as
    # #battle_master_with_known_maneuvers: #spells is a has_many :through
    # association, which only resolves for a persisted owner.
    def spellcaster_with_known_spells(fixture_name)
      character = player_characters(fixture_name)
      character.current_hit_points = character.max_hit_points
      character
    end

    def precision_attack_action(service:, actor:)
      service.send(:available_actions_for, actor:).find do |action|
        action[:type] == :class_feature && action[:class_feature].slug == "battle-master-maneuver-precision-attack"
      end
    end
end
