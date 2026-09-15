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

    def precision_attack_action(service:, actor:)
      service.send(:available_actions_for, actor:).find do |action|
        action[:type] == :class_feature && action[:class_feature].slug == "battle-master-maneuver-precision-attack"
      end
    end
end
