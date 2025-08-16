module AbilityScores
  extend ActiveSupport::Concern

  ABILITY_SCORE_COLUMNS = %w[strength dexterity constitution intelligence wisdom charisma].freeze

  class_methods do
    def delegate_ability_scores_to(target)
      ABILITY_SCORE_COLUMNS.each do |attr|
        delegate attr.to_sym, "#{attr}=".to_sym, "#{attr}_modifier".to_sym, to: target
      end
    end

    def has_ability_score_modifiers
      ABILITY_SCORE_COLUMNS.each do |ability_score|
        define_method("#{ability_score}_modifier") do
          score = send(ability_score)
          (score - 10) / 2
        end
      end
    end
  end
end
