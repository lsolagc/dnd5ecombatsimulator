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

    # The Combat::Participant the character fights as in the service (built by its initialize_state).
    def participant_of(service, character)
      service.send(:all_combatants).find { |participant| participant.character.equal?(character) }
    end
  end
end
