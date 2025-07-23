class Combatant < ApplicationRecord
  include AbilityScoreLogic
  include ConditionAndDamageTypeLogic
end
