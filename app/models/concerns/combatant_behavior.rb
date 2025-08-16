require "active_support/concern"

module CombatantBehavior
  extend ActiveSupport::Concern

  included do
    attr_accessor :current_hit_points
  end

  class_methods do
    def behave_as_combatant
      delegate  :armor_class,
                :max_hit_points,
                :max_hit_points=,
                # :current_hit_points,
                # :current_hit_points=,
                # :initiative,
                # :dead?,
                # :initialize_for_combat,
                to: :combatant
    end
  end

  # ---
  # Instance methods
  # ---

  def initialize_for_combat
    self.current_hit_points = max_hit_points || hit_points_at_level_one
  end

  def dead?
    current_hit_points.nil? || current_hit_points <= 0
  end

  def initiative
    dexterity_modifier
  end
end
