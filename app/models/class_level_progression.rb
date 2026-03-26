class ClassLevelProgression < ApplicationRecord
  belongs_to :player_class

  validates :level, presence: true, inclusion: { in: 1..20 }
  validates :proficiency_bonus, presence: true
  validates :level, uniqueness: { scope: :player_class_id }

  after_find { freeze }
end
