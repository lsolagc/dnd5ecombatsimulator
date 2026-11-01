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
                :defenses,
                to: :combatant
    end
  end

  def initiative
    dexterity_modifier
  end
end
