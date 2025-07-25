module AbilityScoreDelegator
  extend ActiveSupport::Concern

  class_methods do
    def delegate_ability_scores_to(target)
      AbilityScoreLogic::ABILITY_SCORE_COLUMNS.each do |attr|
        delegate attr.to_sym, "#{attr}=".to_sym, "#{attr}_modifier".to_sym, to: target
      end
    end
  end
end
