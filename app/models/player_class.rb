class PlayerClass < ApplicationRecord
  include Tableable

  enum :spellcasting_modifier, [ :intelligence, :wisdom, :charisma ]
  enum :hit_die, [ :d4, :d6, :d8, :d10, :d12 ]

  validates :name, presence: true, uniqueness: true
  validates :hit_die, presence: true

  ##
  # Returns all available hit dice for player classes
  #
  # @return [Hash<String>] List of hit dice (e.g. {"d4" => 0, "d6" => 1, "d8" => 2, "d10" => 3, "d12" => 4})
  #
  # @example Get all available hit dice
  #   PlayerClass.hit_dice #=> {"d4" => 0, "d6" => 1, "d8" => 2, "d10" => 3, "d12" => 4}
  def self.hit_dice
    hit_dies
  end
end
