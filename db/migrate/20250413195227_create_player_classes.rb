class CreatePlayerClasses < ActiveRecord::Migration[8.0]
  def change
    create_table :player_classes do |t|
      t.string :name
      t.string :hit_die
      t.text :description
      t.string :spellcasting_modifier

      t.timestamps
    end
  end
end
