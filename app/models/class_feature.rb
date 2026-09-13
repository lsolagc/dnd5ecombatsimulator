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

  # A feature is part of this marker's subclass tree if it *is* the marker itself, or if it's a
  # subclass_progression pointing back at this marker via subclass_marker_id.
  def subclass_tree_member?(feature)
    return false unless feature_type_subclass?

    feature.id == id || feature.subclass_marker_id == id
  end

  ##
  # Whether +feature+ should be visible to a character with the given +martial_archetype+
  # choice (a ClassFeature of feature_type :subclass, or nil). Non-subclass features (core,
  # optional) are always visible; subclass and subclass_progression features require the
  # character to have chosen the matching archetype.
  def self.visible_for?(feature, martial_archetype:)
    return true unless feature.feature_type_subclass? || feature.feature_type_subclass_progression?
    return false if martial_archetype.nil?

    martial_archetype.subclass_tree_member?(feature)
  end

  private

    def subclass_marker_belongs_to_the_same_subclass_tree
      return if subclass_marker.nil?

      errors.add(:subclass_marker, "must be a subclass-type class feature") unless subclass_marker.feature_type_subclass?

      if subclass_marker.player_class_id != player_class_id
        errors.add(:subclass_marker, "must belong to the same class")
      end
    end
end
