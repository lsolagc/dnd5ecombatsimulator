class SpellSlotProgression < ApplicationRecord
  belongs_to :class_feature

  MAX_SPELL_SLOT_LEVEL = 4

  validates :level, presence: true, inclusion: { in: 1..20 }
  validates :level, uniqueness: { scope: :class_feature_id }
  validates :cantrips_known, :spells_known, :spell_slots_1, :spell_slots_2, :spell_slots_3, :spell_slots_4,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def slots_for(spell_level)
    return 0 unless spell_level.between?(1, MAX_SPELL_SLOT_LEVEL)

    public_send("spell_slots_#{spell_level}")
  end

  def slots_by_level
    (1..MAX_SPELL_SLOT_LEVEL).index_with { |spell_level| slots_for(spell_level) }
  end
end
