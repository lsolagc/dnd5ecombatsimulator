class ClassFeatureUnlock < ApplicationRecord
  belongs_to :class_feature

  enum :action_type, [ :passive, :action, :bonus_action, :reaction, :no_action, :special ], prefix: true
  enum :recharge_type, [ :none, :short_rest, :long_rest, :short_or_long_rest, :turn, :round, :special ], prefix: true

  validates :level, presence: true, inclusion: { in: 1..20 }
  validates :level, uniqueness: { scope: :class_feature_id }
  validates :uses, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
