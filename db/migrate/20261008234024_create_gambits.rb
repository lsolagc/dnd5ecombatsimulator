class CreateGambits < ActiveRecord::Migration[8.0]
  def change
    create_table :gambits do |t|
      # The unique constraint below indexes (owner_type, owner_id, position), which covers owner lookups.
      t.references :owner, polymorphic: true, null: false, index: false
      t.integer :position, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :target, null: false
      t.integer :condition, null: false
      t.integer :condition_value
      t.integer :action_kind, null: false
      t.references :class_feature, foreign_key: true
      t.references :spell, foreign_key: true

      t.timestamps
    end

    add_check_constraint :gambits, "position BETWEEN 1 AND 6", name: "gambits_position_range"
    add_check_constraint :gambits,
      "(action_kind = 0 AND class_feature_id IS NULL AND spell_id IS NULL) OR " \
      "(action_kind = 1 AND class_feature_id IS NOT NULL AND spell_id IS NULL) OR " \
      "(action_kind = 2 AND class_feature_id IS NULL AND spell_id IS NOT NULL)",
      name: "gambits_action_consistency"
    # Deferred so a reorder can permute positions inside one transaction.
    add_unique_constraint :gambits, [ :owner_type, :owner_id, :position ], deferrable: :deferred,
      name: "gambits_owner_position_unique"
  end
end
