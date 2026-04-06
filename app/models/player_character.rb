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
    Dice::AttackRoll.new(
      damage_dice: damage_roll,
      damage_modifier: strength_modifier,
      critical_hit_threshold: critical_hit_threshold
    )
  end

  def critical_hit_threshold
    thresholds = passive_effect_payloads(trigger: "always")
      .select { |payload| payload["kind"] == "modifier" && payload["modifier"] == "critical_hit_threshold" }
      .map { |payload| payload["value"].to_i }
      .select { |value| value.between?(1, 20) }

    thresholds.min || 20
  end

  def passive_effect_payloads(trigger:)
    unlocked_class_feature_unlocks.filter_map do |unlock|
      payload = unlock.effect_payload&.deep_stringify_keys
      next if payload.blank?
      next unless payload["trigger"] == trigger

      payload.merge(
        "feature_slug" => unlock.class_feature.slug,
        "feature_name" => unlock.class_feature.name,
        "unlock_level" => unlock.level
      )
    end
  end

  def damage_roll
    "1d4"
  end

  def get_attacked(attack_roll:)
    if attack_roll.total >= armor_class
      take_damage(amount: attack_roll.damage, damage_type: :bludgeoning)
      { success: true, attack_roll: attack_roll, message: "Hit!" }
    else
      { success: false, attack_roll: attack_roll, message: "Miss!" }
    end
  end

  def take_damage(amount:, damage_type:)
    raise ArgumentError, "Amount must be a positive Integer" unless amount.is_a?(Integer) && amount.positive?
    return if immune_to?(damage_type:)

    if resistant_to?(damage_type:)
      amount = amount / 2
    end

    if vulnerable_to?(damage_type:)
      amount = amount * 2
    end

    self.current_hit_points -= amount

    if current_hit_points <= 0
      self.current_hit_points = 0
    end
  end

  def initialize_combatant
    self.combatant = Combatant.new(combatable: self)
  end

  def class_progression
    player_class.progression_at(level)
  end

  def proficiency_bonus
    class_progression&.proficiency_bonus || 2
  end

  def attacks_per_action
    class_progression&.attacks_per_action || 1
  end

  def can_improve_ability_scores?
    class_progression&.grants_ability_score_improvement? || false
  end

  def level_up!
    increment!(:level)
  end

  def use_class_feature(slug:, targets: [])
    feature = player_class.class_features.find_by!(slug: slug)
    action = Combat::CombatAction.new(
      source_type: :class_feature,
      source_id:   feature.id,
      actor:       self,
      targets:     targets
    )
    Combat::ActionRunner.call(action: action)
  end

  private

    def unlocked_class_feature_unlocks
      ClassFeatureUnlock
        .joins(:class_feature)
        .includes(:class_feature)
        .where(class_features: { player_class_id: player_class_id })
        .where("class_feature_unlocks.level <= ?", level)
    end
end
