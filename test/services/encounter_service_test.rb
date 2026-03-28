require "test_helper"

class EncounterServiceTest < ActiveSupport::TestCase
  setup do
    Random.srand(1234) # For consistent random rolls

    fighter = player_classes(:fighter)

    [
      { level: 1, proficiency_bonus: 2, grants_ability_score_improvement: false, attacks_per_action: 1 },
      { level: 5, proficiency_bonus: 3, grants_ability_score_improvement: false, attacks_per_action: 2 }
    ].each do |attrs|
      progression = ClassLevelProgression.find_or_initialize_by(player_class: fighter, level: attrs[:level])
      progression.assign_attributes(attrs.except(:level))
      progression.save! if progression.changed?
    end
  end

  test "random should be deterministic" do
    n = Random.rand(1..20)
    assert_equal 16, n # This should always return 16 with the set seed
  end

  test "should run encounter with two parties" do
    party_one = [ player_characters(:aragorn) ]
    party_two = [ player_characters(:aragorn_copy) ]

    encounter_service = EncounterService.new(party_one:, party_two:, reset_hit_points: true)
    encounter_result = encounter_service.call

    expected_result = {
      winner: party_two.map(&:name),
      number_of_rounds: 6
    }

    assert_equal expected_result, encounter_result.encounter_log[:end_of_encounter]
  end

  test "fighter with extra attack performs two attacks per turn" do
    party_one = [ player_characters(:thorin) ]
    party_two = [ player_characters(:aragorn), player_characters(:aragorn_copy) ]

    encounter_result = EncounterService.new(party_one:, party_two:, reset_hit_points: true).call

    round_entries = encounter_result.encounter_log[:rounds].values.select { |round| round.is_a?(Array) }
    thorin_turns = round_entries.flatten.select { |entry| entry[:combatant] == "Thorin" }

    assert thorin_turns.any?
    assert thorin_turns.all? { |entry| entry[:attacks].size == 2 }

    first_turn = thorin_turns.first
    first_attack = first_turn[:attacks].first
    assert_equal first_attack[:target], first_turn[:target]
    assert_equal first_attack[:success], first_turn[:success]
  end
end
