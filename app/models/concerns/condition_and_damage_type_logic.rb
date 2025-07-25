require "active_support/concern"

module ConditionAndDamageTypeLogic
  extend ActiveSupport::Concern

  included do
    validates :resistances, :vulnerabilities, :immunities, condition_and_damage_type_format: true
  end

  # ---
  # Instance methods
  # ---

  def vulnerable_to?(damage_type: nil, condition: nil)
    if damage_type
      vulnerabilities.dig("damage_types", damage_type.to_s)
    elsif condition
      vulnerabilities.dig("conditions", condition.to_s)
    else
      false
    end
  end

  def resistant_to?(damage_type: nil, condition: nil)
    if damage_type
      resistances.dig("damage_types", damage_type.to_s)
    elsif condition
      resistances.dig("conditions", condition.to_s)
    else
      false
    end
  end

  def immune_to?(damage_type: nil, condition: nil)
    if damage_type
      immunities.dig("damage_types", damage_type.to_s)
    elsif condition
      immunities.dig("conditions", condition.to_s)
    else
      false
    end
  end
end
