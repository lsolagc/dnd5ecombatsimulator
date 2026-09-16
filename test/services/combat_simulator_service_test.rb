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
