class AddEffectPayloadToClassFeatureUnlocks < ActiveRecord::Migration[8.0]
  def change
    add_column :class_feature_unlocks, :effect_payload, :jsonb
  end
end
