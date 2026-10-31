ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # The Combat::Participant the character fights as: in a Combat::Encounter, or a Combat::Simulator's (after #call).
    def participant_of(source, character)
      encounter = source.is_a?(Combat::Encounter) ? source : source.encounter
      encounter.participants.find { |participant| participant.character.equal?(character) }
    end

    # A fight between the sheets as Combat::Simulator builds it (participants in party order), before initiative:
    # in party order, or the given order of sheets.
    def build_encounter(party_one:, party_two:, hit_points: {}, initiative_order: nil)
      party = ->(sheets) { sheets.map { |sheet| Combat::Participant.new(sheet, hit_points: hit_points[sheet.combatant.id]) } }
      encounter = Combat::Encounter.new(party_one: party.(party_one), party_two: party.(party_two))
      encounter.initiative_order = initiative_order.map { |sheet| participant_of(encounter, sheet) } if initiative_order
      encounter
    end

    # The turns of the encounter as Combat::Simulator plays them: rng is a simulator's for that seed, the rules
    # the actors' own gambits (or the copy).
    def build_turn_executor(encounter, rng: Random.new(1), gambits: nil)
      Combat::TurnExecutor.new(encounter:, rng:, policy: Combat::GambitPolicy.new(encounter:, gambits:))
    end
  end
end
