class CreateClassLevelProgressions < ActiveRecord::Migration[8.0]
  def change
    create_table :class_level_progressions do |t|
      t.references :player_class, null: false, foreign_key: true
      t.integer :level, null: false
      t.integer :proficiency_bonus, null: false
      t.boolean :grants_ability_score_improvement, null: false, default: false

      t.timestamps
    end

    add_index :class_level_progressions, [ :player_class_id, :level ], unique: true
  end
end
