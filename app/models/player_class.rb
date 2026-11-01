class PlayerClass < ApplicationRecord
  enum :spellcasting_modifier, [ :intelligence, :wisdom, :charisma ]
  enum :hit_die, [ :d4, :d6, :d8, :d10, :d12 ]

  has_many :class_level_progressions, dependent: :destroy
  has_many :class_features, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :hit_die, presence: true

  def progression_at(level)
    class_level_progressions.find_by(level: level)
  end

  # The hit_die enum's { name => value } mapping (what Rails calls hit_dies).
  def self.hit_dice
    hit_dies
  end
end
