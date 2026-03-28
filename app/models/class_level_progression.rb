class ClassLevelProgression < ApplicationRecord
  belongs_to :player_class

  validates :level, presence: true, inclusion: { in: 1..20 }
  validates :proficiency_bonus, presence: true
  validates :attacks_per_action, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :level, uniqueness: { scope: :player_class_id }

  after_find { freeze }
end
