class ClassFeature < ApplicationRecord
  belongs_to :player_class
  belongs_to :subclass_marker, class_name: "ClassFeature", optional: true, inverse_of: :subclass_progressions
  has_many :subclass_progressions, class_name: "ClassFeature", foreign_key: :subclass_marker_id,
                                    inverse_of: :subclass_marker
  has_many :class_feature_unlocks, dependent: :destroy
  has_many :spell_slot_progressions, dependent: :destroy

  enum :feature_type, [ :core, :optional, :subclass, :subclass_progression ], prefix: true
  enum :action_type, [ :passive, :action, :bonus_action, :reaction, :no_action, :special ], prefix: true
  enum :recharge_type, [ :none, :short_rest, :long_rest, :short_or_long_rest, :turn, :round, :special ], prefix: true
  # Ability of a subclass's spellcasting (e.g. Eldritch Knight uses INT); a feature without one falls back to the class's.
  enum :spellcasting_ability, [ :intelligence, :wisdom, :charisma ], prefix: true

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :player_class_id }
  validates :description, presence: true
  validates :source_book, presence: true
  validates :action_type, presence: true
  validates :recharge_type, presence: true
  validates :feature_type, presence: true
  validates :grants_spellcasting, inclusion: { in: [ true, false ] }
  validates :subclass_marker, presence: true, if: :feature_type_subclass_progression?
  validate :subclass_marker_belongs_to_the_same_subclass_tree
  validate :spellcasting_ability_is_known, if: :grants_spellcasting

  # Whether this is a maneuver of +combat_superiority+ (the resource_pool feature, or nil): .okf/models/class-feature.md (Maneuvers)
  def maneuver_of?(combat_superiority)
    !combat_superiority.nil? && resource_name.present? && resource_name == combat_superiority.resource_name
  end

  # The effect in force at +level+ (none: a preset's, the highest unlock's), or nil: .okf/models/class-feature-unlock.md (Overview)
  # Filters the loaded unlocks (PlayerCharacter#feature_unlocks preloads them).
  def effect_payload_at(level = nil)
    class_feature_unlocks.select { |unlock| unlock.effect_payload.present? && (level.nil? || unlock.level <= level) }
                         .max_by(&:level)&.effect_payload&.deep_stringify_keys
  end

  # The effect at +level+ if the simulator can choose it as a turn action: a heal or damage with no
  # passive trigger. Nil otherwise.
  def action_payload_at(level = nil)
    payload = effect_payload_at(level)
    payload if payload && payload["kind"].in?(%w[heal damage]) && payload["trigger"].blank?
  end

  # A feature is part of this marker's subclass tree if it *is* the marker itself, or if it's a
  # subclass_progression pointing back at this marker via subclass_marker_id.
  def subclass_tree_member?(feature)
    return false unless feature_type_subclass?

    feature.id == id || feature.subclass_marker_id == id
  end

  # Whether +feature+ is visible to a character with these choices: .okf/models/class-feature.md (Visibility)
  def self.visible_for?(feature, martial_archetype:, fighting_style: nil)
    return feature.id == fighting_style&.id if feature.feature_type_optional?
    return true unless feature.feature_type_subclass? || feature.feature_type_subclass_progression?
    return false if martial_archetype.nil?

    martial_archetype.subclass_tree_member?(feature)
  end

  private

    def spellcasting_ability_is_known
      return if spellcasting_ability.present? || player_class&.spellcasting_modifier.present?

      errors.add(:spellcasting_ability, "must be set when the class has no spellcasting ability of its own")
    end

    def subclass_marker_belongs_to_the_same_subclass_tree
      return if subclass_marker.nil?

      errors.add(:subclass_marker, "must be a subclass-type class feature") unless subclass_marker.feature_type_subclass?

      if subclass_marker.player_class_id != player_class_id
        errors.add(:subclass_marker, "must belong to the same class")
      end
    end
end
