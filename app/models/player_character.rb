class PlayerCharacter < ApplicationRecord
  include AbilityScoreDelegator

  belongs_to :player_class
  has_one :combatant, as: :combatable, touch: true

  delegate :hit_die, :spellcasting_modifier, to: :player_class
  delegate_ability_scores_to :combatant
  delegate :armor_class, to: :combatant

  before_validation :initialize_combatant, if: -> { combatant.nil? }

  attr_accessor :current_hit_points, :max_hit_points

  def initiative
    dexterity_modifier
  end

  def roll_hit_points(for_level: 1)
    return ArgumentError.new("for_level must be an Integer") unless for_level.is_a?(Integer)
    return ArgumentError.new("Hit points can only be rolled for levels greater than 1") if for_level && for_level < 1

    additional_hit_points = 0
    if for_level && for_level > 1
      additional_levels = for_level - 1
      additional_levels.times do
        additional_hit_points += rand(1..hit_die_value) + constitution_modifier
      end
    end

    self.max_hit_points = hit_points_at_level_one + additional_hit_points
  end

  def hit_points_at_level_one
    hit_die_value + constitution_modifier
  end

  def hit_die_value
    hit_die.to_s.delete("d").to_i
  end

  def initialize_for_combat
    self.current_hit_points = max_hit_points || hit_points_at_level_one
  end

  def attack(target:)
    raise ArgumentError, "Target must be a Combatant" unless target.respond_to?(:combatant)

    attack_roll = rand(1..20)
    if attack_roll >= target.armor_class
      damage = rand(1..4) + strength_modifier
      target.take_damage(amount: damage, damage_type: :bludgeoning)
      { success: true, attack_roll: attack_roll, damage: damage, message: "Hit!" }
    else
      { success: false, attack_roll: attack_roll, message: "Miss!" }
    end
  end

  def take_damage(amount:, damage_type:)
    raise ArgumentError, "Amount must be a positive Integer" unless amount.is_a?(Integer) && amount.positive?

    self.current_hit_points ||= max_hit_points
    self.current_hit_points -= amount

    if current_hit_points <= 0
      self.current_hit_points = 0
    end
  end

  def dead?
    current_hit_points.nil? || current_hit_points <= 0
  end

  def initialize_combatant
    self.combatant = Combatant.new(combatable: self)
  end
end
