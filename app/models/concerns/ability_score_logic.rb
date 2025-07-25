require "active_support/concern"

module AbilityScoreLogic
  extend ActiveSupport::Concern

  ABILITY_SCORE_COLUMNS = %w[strength dexterity constitution intelligence wisdom charisma].freeze

  included do |base|
    ABILITY_SCORE_COLUMNS.each do |ability_score|
      define_method("#{ability_score}_modifier") do
        score = send(ability_score)
        (score - 10) / 2
      end
    end
  end
end
