class AddAttacksPerActionToClassLevelProgressions < ActiveRecord::Migration[8.0]
  def change
    add_column :class_level_progressions, :attacks_per_action, :integer, null: false, default: 1
  end
end
