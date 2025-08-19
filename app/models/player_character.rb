class PlayerCharacter < ApplicationRecord
  include AbilityScores
  include CombatantBehavior

  belongs_to :player_class
  delegate :hit_die, :spellcasting_modifier, to: :player_class

  has_one :combatant, as: :combatable, touch: true
  behave_as_combatant
  delegate_ability_scores_to :combatant

  before_create :initialize_combatant, if: -> { combatant.nil? }
  before_create :setup_hit_points

  def setup_hit_points
    case level
    when 1
      self.max_hit_points = hit_points_at_level_one
    else
      self.max_hit_points = hit_points_at_level_one + roll_hit_points(for_level: level)
    end
  end

  def roll_hit_points(for_level: 1)
    return ArgumentError.new("for_level must be an Integer") unless for_level.is_a?(Integer)
    return ArgumentError.new("Hit points can only be rolled for levels greater than 1") if for_level && for_level < 1

    additional_hit_points = 0
    if for_level && for_level > 1
      additional_levels = for_level - level
      additional_levels.times do
        additional_hit_points += Dice.send(hit_die) + constitution_modifier
      end
    end

    additional_hit_points
  end

  def hit_points_at_level_one
    hit_die_value + constitution_modifier
  end

  def hit_die_value
    hit_die.to_s.delete("d").to_i
  end

  def roll_an_attack
    attack_roll = Dice.d20
    damage_roll = Dice.d4(modifier: strength_modifier)

    [ attack_roll, damage_roll ]
  end

  def get_attacked(attack_roll:, damage_roll:)
    if attack_roll.total >= armor_class
      take_damage(amount: damage_roll.total, damage_type: :bludgeoning)
      { success: true, attack_roll: attack_roll.total, damage: damage_roll.total, message: "Hit!" }
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

  def initialize_combatant
    self.combatant = Combatant.new(combatable: self)
  end
end
