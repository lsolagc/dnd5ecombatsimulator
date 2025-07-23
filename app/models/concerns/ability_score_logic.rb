require "active_support/concern"

module AbilityScoreLogic
  extend ActiveSupport::Concern

  included do |base|
    base.ability_score_columns.each do |ability_score|
      define_method("#{ability_score}_modifier") do
        score = send(ability_score)
        (score - 10) / 2
      end
    end
  end

  class_methods do
    def ability_score_columns
      %w[strength dexterity constitution intelligence wisdom charisma]
    end
  end
end
