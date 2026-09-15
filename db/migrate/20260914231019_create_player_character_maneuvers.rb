class CreatePlayerCharacterManeuvers < ActiveRecord::Migration[8.0]
  def change
    create_table :player_character_maneuvers do |t|
      t.references :player_character, null: false, foreign_key: true
      t.references :maneuver, null: false, foreign_key: { to_table: :class_features }

      t.timestamps
    end

    add_index :player_character_maneuvers, [ :player_character_id, :maneuver_id ], unique: true, name: "index_pc_maneuvers_on_character_and_maneuver"
  end
end
