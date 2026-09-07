class CreateSpellSlotProgressions < ActiveRecord::Migration[8.0]
  def change
    create_table :spell_slot_progressions do |t|
      t.references :class_feature, null: false, foreign_key: true
      t.integer :level, null: false
      t.integer :cantrips_known, null: false, default: 0
      t.integer :spells_known, null: false, default: 0
      t.integer :spell_slots_1, null: false, default: 0
      t.integer :spell_slots_2, null: false, default: 0
      t.integer :spell_slots_3, null: false, default: 0
      t.integer :spell_slots_4, null: false, default: 0

      t.timestamps
    end

    add_index :spell_slot_progressions, [ :class_feature_id, :level ], unique: true
  end
end
