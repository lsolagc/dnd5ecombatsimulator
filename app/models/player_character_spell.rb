class PlayerCharacterSpell < ApplicationRecord
  belongs_to :player_character
  belongs_to :spell

  validates :spell_id, uniqueness: { scope: :player_character_id }
end
