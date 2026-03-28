class ClassFeature < ApplicationRecord
  belongs_to :player_class
  has_many :class_feature_unlocks, dependent: :destroy

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
end
