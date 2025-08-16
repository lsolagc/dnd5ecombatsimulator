class Combatant < ApplicationRecord
  include AbilityScores
  include ConditionAndDamageTypeLogic

  delegated_type :combatable, types: %w[ PlayerCharacter ]

  has_ability_score_modifiers

  attr_accessor :current_hit_points

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
