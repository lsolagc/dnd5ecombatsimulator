class CreateClassFeatures < ActiveRecord::Migration[8.0]
  def change
    create_table :class_features do |t|
      t.references :player_class, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description, null: false
      t.integer :feature_type, null: false, default: 0
      t.integer :action_type, null: false, default: 0
      t.string :resource_name
      t.integer :recharge_type, null: false, default: 0
      t.boolean :grants_spellcasting, null: false, default: false
      t.string :source_book, null: false, default: "PHB 2014"
      t.string :source_reference
      t.text :notes

      t.timestamps
    end

    add_index :class_features, [ :player_class_id, :slug ], unique: true
  end
end
