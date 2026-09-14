class AddFightingStyleToPlayerCharacters < ActiveRecord::Migration[8.0]
  def change
    add_reference :player_characters, :fighting_style, null: true, foreign_key: { to_table: :class_features }
  end
end
