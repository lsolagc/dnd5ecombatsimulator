# One FFXII-style turn rule: "target: condition → action". A combatant evaluates its enabled gambits
# by position (1 = highest priority) in CombatSimulatorService; the first one with a valid target and
# an available action decides the turn.
class Gambit < ApplicationRecord
  MAX_PER_OWNER = 6

  TARGET_LABELS = { "self" => "Self", "ally" => "Aliado", "enemy" => "Inimigo" }.freeze
  # Targets a rule may use for each natural target of its action (the effect payload's "target").
  COMPATIBLE_TARGETS = { "self" => %w[self], "enemy" => %w[enemy], "ally" => %w[ally self] }.freeze
  # The conditions as the gambits screen offers them (condition_label renders them with their value).
  CONDITION_LABELS = {
    "any" => "Qualquer", "hp_below" => "HP abaixo de (%)", "hp_above" => "HP acima de (%)", "lowest_hp" => "Menor HP",
    "highest_hp" => "Maior HP", "marked" => "Marcado", "unmarked" => "Não marcado", "resource_at_least" => "Recurso no mínimo"
  }.freeze
  CONDITIONS_WITH_VALUE = %w[hp_below hp_above resource_at_least].freeze

  belongs_to :owner, polymorphic: true
  belongs_to :class_feature, optional: true
  belongs_to :spell, optional: true

  # Messages are whole pt-BR sentences: the gambits screen shows them as they are (errors.map(&:message)).
  # validate: makes a tampered enum value a validation error instead of an ArgumentError.
  enum :target, { self: 0, ally: 1, enemy: 2 }, prefix: true, validate: { message: "Alvo inválido" }
  # Append new conditions with new values; never renumber (stored as integers).
  enum :condition, { any: 0, hp_below: 1, lowest_hp: 2, hp_above: 3, highest_hp: 4, marked: 5, unmarked: 6, resource_at_least: 7 },
                    prefix: true, validate: { message: "Condição inválida" }
  enum :action_kind, { attack: 0, class_feature: 1, spell: 2 }, prefix: :action, validate: { message: "Ação inválida" }

  validates :position, presence: true, inclusion: { in: 1..MAX_PER_OWNER, message: "A posição vai de 1 a #{MAX_PER_OWNER}" }
  validates :condition_value, numericality: { only_integer: true, in: 1..99, message: "O valor da condição vai de 1 a 99 (%)" },
                              if: -> { condition_hp_below? || condition_hp_above? }
  validates :condition_value, numericality: { only_integer: true, in: 1..20, message: "O valor do recurso vai de 1 a 20" },
                              if: :condition_resource_at_least?
  validates :condition_value, absence: { message: "Esta condição não usa valor" }, unless: -> { condition.in?(CONDITIONS_WITH_VALUE) }
  validate :action_matches_its_kind
  validate :target_fits_the_action
  validate :resource_condition_has_a_resource
  validate :owner_has_room

  # The attributes a SimulationBatch copies (and the simulator rebuilds unsaved gambits from).
  SNAPSHOT_ATTRIBUTES = %w[position enabled target condition condition_value action_kind class_feature_id spell_id].freeze

  # The rule as copied into a batch: its attributes plus the readable texts at copy time, so the log
  # never depends on the database (a renamed feature or spell, an edited rule).
  def snapshot
    attributes.slice(*SNAPSHOT_ATTRIBUTES).merge(
      "target_label" => TARGET_LABELS[target], "condition_label" => condition_label, "action_label" => action_label, "label" => label
    )
  end

  # A combatant's gambits as the log shows them, from snapshots: every rule (enabled or not) in priority
  # order, and "aleatório" when none is enabled (the simulator then picks at random).
  def self.log_section(id:, name:, snapshots:)
    rules = snapshots.sort_by { |rule| rule["position"] }
    {
      id:, name:,
      mode: rules.any? { |rule| rule["enabled"] } ? "gambits" : "aleatório",
      rules: rules.map do |rule|
        { position: rule["position"], enabled: rule["enabled"], target: rule["target_label"], condition: rule["condition_label"],
          action: rule["action_label"], rule: rule["label"] }
      end
    }
  end

  # Replaces the rules of `to` with new copies of the rules of `from` (presets: save, overwrite and apply),
  # in one transaction holding a row lock on `to`. Copies take positions 1..n in the source's priority
  # order; being new rows, they keep no link to the source. Returns false, changing nothing, when `from`
  # has no rules. Each copy is validated for `to` (a character's level, see #active_feature_payload): the
  # first one that does not hold raises ActiveRecord::RecordInvalid, changing nothing.
  def self.copy_rules(from:, to:)
    transaction do
      to.lock!
      rules = from.gambits.reorder(:position).to_a
      next false if rules.empty?

      where(owner: to).delete_all
      rules.each.with_index(1) do |rule, position|
        create!(rule.attributes.slice(*SNAPSHOT_ATTRIBUTES).merge("owner" => to, "position" => position))
      end
      true
    end
  ensure
    to.gambits.reset
  end

  def label
    "#{TARGET_LABELS[target]}: #{condition_label} → #{action_label}"
  end

  def condition_label
    case condition
    when "any" then "qualquer"
    when "hp_below" then "HP < #{condition_value}%"
    when "lowest_hp" then "menor HP"
    when "hp_above" then "HP > #{condition_value}%"
    when "highest_hp" then "maior HP"
    when "marked" then "marcado"
    when "unmarked" then "não marcado"
    when "resource_at_least" then "recurso ≥ #{condition_value}"
    end
  end

  def action_label
    case action_kind
    when "attack" then "Ataque"
    when "class_feature" then class_feature&.name
    when "spell" then spell&.name
    end
  end

  # The action as one select value ("attack", "class_feature:ID", "spell:ID"), the encoding of
  # PlayerCharacter#gambit_action_options and GambitsController.
  def action_choice
    action_attack? ? "attack" : "#{action_kind}:#{class_feature_id || spell_id}"
  end

  # The action's natural target ("self", "ally" or "enemy"); nil when it has no active effect.
  def action_target
    case action_kind
    when "attack" then "enemy"
    when "class_feature" then action_surge? ? "self" : active_feature_payload&.dig("target")
    when "spell" then spell&.effect_payload&.dig("target")
    end
  end

  # Action Surge has no effect payload: the simulator runs it as a gambit action of its own (identified
  # by name, like CombatSimulatorService#action_surge_unlock_for).
  def action_surge?
    action_class_feature? && class_feature&.name == "Action Surge"
  end

  # The feature's effect if the simulator can choose it as an action (ClassFeature#action_payload_at), at
  # the owner's level; a preset has none, so its rules read the feature's highest unlock. A feature with no
  # effect yet at the owner's level is an action the owner lacks: read like a preset's, so the rule stays
  # valid and is skipped at runtime, as a feature from another subclass is.
  def active_feature_payload
    return if class_feature.nil?

    level = owner.try(:level)
    level = nil if level && class_feature.effect_payload_at(level).nil?
    class_feature.action_payload_at(level)
  end

  private

    def action_matches_its_kind
      case action_kind
      when "attack"
        errors.add(:base, "Um ataque não leva feature nem magia") if class_feature_id || spell_id
      when "class_feature"
        errors.add(:class_feature, "Escolha a feature da ação") if class_feature.nil?
        errors.add(:spell, "Uma ação de feature não leva magia") if spell_id
      when "spell"
        errors.add(:spell, "Escolha a magia da ação") if spell.nil?
        errors.add(:class_feature, "Uma ação de magia não leva feature") if class_feature_id
      end
    end

    def target_fits_the_action
      return if target.nil? || %i[base class_feature spell].any? { |attribute| errors.include?(attribute) }

      natural = action_target
      if natural.nil?
        errors.add(:base, "Esta ação não tem efeito ativo no simulador")
      elsif !COMPATIBLE_TARGETS.fetch(natural, []).include?(target)
        errors.add(:target, "O alvo não combina com a ação (ela mira #{TARGET_LABELS[natural]})")
      end
    end

    # Ataque and cantrips spend nothing, so "recurso ≥ X" has nothing to measure.
    def resource_condition_has_a_resource
      return unless condition_resource_at_least?

      errors.add(:condition, "\"Recurso no mínimo\" precisa de uma ação que gaste recurso") if action_attack? || (action_spell? && spell&.cantrip?)
    end

    def owner_has_room
      return if owner.nil?

      others = owner.gambits.to_a.reject { |gambit| gambit.equal?(self) || (persisted? && gambit.id == id) }
      errors.add(:base, "No máximo #{MAX_PER_OWNER} gambits") if others.size >= MAX_PER_OWNER
    end
end
