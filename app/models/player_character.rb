class PlayerCharacter < ApplicationRecord
  include AbilityScoreDelegator

  belongs_to :player_class
  has_one :combatant, as: :combatable, touch: true

  delegate :hit_die, :spellcasting_modifier, to: :player_class
  delegate_ability_scores_to :combatant
end
