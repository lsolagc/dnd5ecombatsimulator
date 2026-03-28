class CreateClassFeatureUnlocks < ActiveRecord::Migration[8.0]
  def change
    create_table :class_feature_unlocks do |t|
      t.references :class_feature, null: false, foreign_key: true
      t.integer :level, null: false
      t.integer :action_type
      t.integer :recharge_type
      t.integer :uses
      t.string :uses_formula
      t.string :resource_name
      t.text :description
      t.text :notes

      t.timestamps
    end

    add_index :class_feature_unlocks, [ :class_feature_id, :level ], unique: true
  end
end
