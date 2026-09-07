class CreatePlayerCharacterSpells < ActiveRecord::Migration[8.0]
  def change
    create_table :player_character_spells do |t|
      t.references :player_character, null: false, foreign_key: true
      t.references :spell, null: false, foreign_key: true

      t.timestamps
    end

    add_index :player_character_spells, [ :player_character_id, :spell_id ], unique: true, name: "index_pc_spells_on_character_and_spell"
  end
end
