class CreateSpells < ActiveRecord::Migration[8.0]
  def change
    create_table :spells do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :level, null: false
      t.string :school, null: false
      t.text :description, null: false
      t.text :notes
      t.jsonb :effect_payload

      t.timestamps
    end

    add_index :spells, :slug, unique: true
  end
end
