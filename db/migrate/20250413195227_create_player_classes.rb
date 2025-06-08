class CreatePlayerClasses < ActiveRecord::Migration[8.0]
  def change
    create_table :player_classes do |t|
      t.string :name
      t.integer :hit_die, null: false, default: 0
      t.text :description
      t.integer :spellcasting_modifier, null: false, default: 0

      t.timestamps
    end
  end
end
