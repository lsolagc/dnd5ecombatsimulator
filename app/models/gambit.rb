# One FFXII-style turn rule: "target: condition → action". A combatant evaluates its enabled gambits
# by position (1 = highest priority) in CombatSimulatorService; the first one with a valid target and
# an available action decides the turn.
class Gambit < ApplicationRecord
  MAX_PER_OWNER = 6

  TARGET_LABELS = { "self" => "Self", "ally" => "Aliado", "enemy" => "Inimigo" }.freeze
  # Targets a rule may use for each natural target of its action (the effect payload's "target").
  COMPATIBLE_TARGETS = { "self" => %w[self], "enemy" => %w[enemy], "ally" => %w[ally self] }.freeze

  belongs_to :owner, polymorphic: true
  belongs_to :class_feature, optional: true
  belongs_to :spell, optional: true

  enum :target, { self: 0, ally: 1, enemy: 2 }, prefix: true
  # Append new conditions with new values; never renumber (stored as integers).
  enum :condition, { any: 0, hp_below: 1, lowest_hp: 2 }, prefix: true
  enum :action_kind, { attack: 0, class_feature: 1, spell: 2 }, prefix: :action

  validates :position, presence: true, inclusion: { in: 1..MAX_PER_OWNER }
  validates :target, :condition, :action_kind, presence: true
  validates :condition_value, numericality: { only_integer: true, in: 1..99 }, if: :condition_hp_below?
  validates :condition_value, absence: true, unless: :condition_hp_below?
  validate :action_matches_its_kind
  validate :target_fits_the_action
  validate :owner_has_room

  def label
    "#{TARGET_LABELS[target]}: #{condition_label} → #{action_label}"
  end

  def condition_label
    case condition
    when "any" then "qualquer"
    when "hp_below" then "HP < #{condition_value}%"
    when "lowest_hp" then "menor HP"
    end
  end

  def action_label
    case action_kind
    when "attack" then "Ataque"
    when "class_feature" then class_feature&.name
    when "spell" then spell&.name
    end
  end

  # The action's natural target ("self", "ally" or "enemy"); nil when it has no active effect.
  def action_target
    case action_kind
    when "attack" then "enemy"
    when "class_feature" then active_feature_payload&.dig("target")
    when "spell" then spell&.effect_payload&.dig("target")
    end
  end

  # The feature's effect at its highest unlock level, if the simulator can choose it as an action: a
  # heal or damage that is not a passive trigger (same filter as CombatSimulatorService#available_actions_for).
  # Not tied to the owner's level, since a preset has none.
  def active_feature_payload
    return if class_feature.nil?

    payload = class_feature.class_feature_unlocks.where.not(effect_payload: nil).order(level: :desc).first&.effect_payload
    payload if payload && payload["kind"].in?(%w[heal damage]) && payload["trigger"].blank?
  end

  private

    def action_matches_its_kind
      case action_kind
      when "attack"
        errors.add(:base, "an attack takes no class feature or spell") if class_feature_id || spell_id
      when "class_feature"
        errors.add(:class_feature, "must be set") if class_feature.nil?
        errors.add(:spell, "must be blank for a class feature") if spell_id
      when "spell"
        errors.add(:spell, "must be set") if spell.nil?
        errors.add(:class_feature, "must be blank for a spell") if class_feature_id
      end
    end

    def target_fits_the_action
      return if target.nil? || %i[base class_feature spell].any? { |attribute| errors.include?(attribute) }

      natural = action_target
      if natural.nil?
        errors.add(:base, "the action has no active effect")
      elsif !COMPATIBLE_TARGETS.fetch(natural, []).include?(target)
        errors.add(:target, "does not fit the action (it targets #{natural})")
      end
    end

    def owner_has_room
      return if owner.nil?

      others = owner.gambits.to_a.reject { |gambit| gambit.equal?(self) || (persisted? && gambit.id == id) }
      errors.add(:base, "an owner can have at most #{MAX_PER_OWNER} gambits") if others.size >= MAX_PER_OWNER
    end
end
