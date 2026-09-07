class Spell < ApplicationRecord
  has_many :player_character_spells, dependent: :destroy
  has_many :player_characters, through: :player_character_spells

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :level, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 9 }
  validates :school, presence: true
  validates :description, presence: true

  def cantrip?
    level.zero?
  end
end
