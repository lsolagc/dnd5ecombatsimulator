require "test_helper"

class EncounterServiceTest < ActiveSupport::TestCase
  setup do
    Random.srand(1234) # For consistent random rolls
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
end
