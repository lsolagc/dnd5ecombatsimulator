class Combatant < ApplicationRecord
  include AbilityScoreLogic
  include ConditionAndDamageTypeLogic

  delegated_type :combatable, types: %w[ PlayerCharacter ]
end
