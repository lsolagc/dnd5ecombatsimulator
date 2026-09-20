class AddSpellcastingAbilityToClassFeatures < ActiveRecord::Migration[8.0]
  def change
    add_column :class_features, :spellcasting_ability, :integer
  end
end
