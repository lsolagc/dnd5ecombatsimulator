class Combatant < ApplicationRecord
  include AbilityScores
  include ConditionAndDamageTypeLogic

  delegated_type :combatable, types: %w[ PlayerCharacter ]

  has_ability_score_modifiers
end
