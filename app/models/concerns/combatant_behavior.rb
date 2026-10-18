require "active_support/concern"

module CombatantBehavior
  extend ActiveSupport::Concern

  class_methods do
    def behave_as_combatant
      delegate  :armor_class,
                :max_hit_points,
                :max_hit_points=,
                :attack_bonus,
                :damage_dice,
                :damage_type,
                :immune_to?,
                :resistant_to?,
                :vulnerable_to?,
                to: :combatant
    end
  end

  # ---
  # Instance methods
  # ---

  def initiative
    dexterity_modifier
  end
end
