class CreatePlayerCharacters < ActiveRecord::Migration[8.0]
  def change
    create_table :player_characters do |t|
      t.string :name, null: false
      t.integer :level, default: 1
      t.references :player_class, null: false, foreign_key: true

      t.timestamps
    end
  end
end
