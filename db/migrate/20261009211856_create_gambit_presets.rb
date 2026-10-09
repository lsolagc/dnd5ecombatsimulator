class CreateGambitPresets < ActiveRecord::Migration[8.0]
  def change
    create_table :gambit_presets do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :gambit_presets, "lower(name)", unique: true, name: "index_gambit_presets_on_lower_name"
  end
end
