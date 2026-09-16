class PlayerCharacterSpell < ApplicationRecord
  belongs_to :player_character
  belongs_to :spell

  ELDRITCH_KNIGHT_ARCHETYPE_SLUG = "martial-archetype-eldritch-knight"
  ELDRITCH_KNIGHT_ALLOWED_SCHOOLS = %w[abjuration evocation].freeze

  validates :spell_id, uniqueness: { scope: :player_character_id }
  validate :school_allowed_for_eldritch_knight
  validate :within_known_spells_limit

  private

    def school_allowed_for_eldritch_knight
      return unless spell && player_character&.martial_archetype&.slug == ELDRITCH_KNIGHT_ARCHETYPE_SLUG
      return if ELDRITCH_KNIGHT_ALLOWED_SCHOOLS.include?(spell.school)

      errors.add(:spell, "must be abjuration or evocation for an Eldritch Knight")
    end

    def within_known_spells_limit
      return unless spell && player_character

      progression = applicable_spell_slot_progression
      return unless progression

      already_known = player_character.player_character_spells.where.not(id: id).includes(:spell)

      if spell.cantrip?
        count = already_known.count { |pcs| pcs.spell.cantrip? }
        limit = progression.cantrips_known
        errors.add(:spell, "exceeds the number of cantrips known (#{limit})") if count >= limit
      else
        count = already_known.count { |pcs| !pcs.spell.cantrip? }
        limit = progression.spells_known
        errors.add(:spell, "exceeds the number of spells known (#{limit})") if count >= limit
      end
    end

    def applicable_spell_slot_progression
      feature = player_character.spellcasting_feature
      return nil unless feature

      feature.spell_slot_progressions
             .where("level <= ?", player_character.level)
             .order(level: :desc)
             .first
    end
end
