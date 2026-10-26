require "active_support/concern"

module ConditionAndDamageTypeLogic
  extend ActiveSupport::Concern

  included do
    validates :resistances, :vulnerabilities, :immunities, condition_and_damage_type_format: true
  end
end
