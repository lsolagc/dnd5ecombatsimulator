class PlayerCharacterManeuver < ApplicationRecord
  # Battle Master "maneuvers known" table (PHB 2014): minimum character level required
  # to know that many maneuvers.
  KNOWN_MANEUVERS_BY_LEVEL = { 3 => 3, 7 => 5, 10 => 7, 15 => 9 }.freeze

  belongs_to :player_character
  belongs_to :maneuver, class_name: "ClassFeature"

  validates :maneuver_id, uniqueness: { scope: :player_character_id }
  validate :maneuver_is_a_battle_master_maneuver
  validate :maneuver_matches_the_character_class
  validate :known_maneuvers_within_level_limit

  def self.known_maneuvers_limit(level:)
    KNOWN_MANEUVERS_BY_LEVEL.select { |min_level, _| level >= min_level }.values.max || 0
  end

  private

    def maneuver_is_a_battle_master_maneuver
      return if maneuver.nil? || player_character.nil?

      unless maneuver.feature_type_subclass_progression? && maneuver.resource_name == combat_superiority_resource_name
        errors.add(:maneuver, "must be a Battle Master maneuver")
      end
    end

    def maneuver_matches_the_character_class
      return if maneuver.nil? || player_character.nil?

      if maneuver.player_class_id != player_character.player_class_id
        errors.add(:maneuver, "must belong to the character's class")
      end
    end

    def known_maneuvers_within_level_limit
      return if player_character.nil?

      limit = self.class.known_maneuvers_limit(level: player_character.level)
      already_known = player_character.player_character_maneuvers.where.not(id: id).count

      if already_known >= limit
        errors.add(:maneuver, "exceeds the number of maneuvers known at the character's level")
      end
    end

    def combat_superiority_resource_name
      ClassFeature.find_by(player_class_id: player_character.player_class_id, name: "Combat Superiority")&.resource_name
    end
end
