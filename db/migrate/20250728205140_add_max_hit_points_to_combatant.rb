class AddMaxHitPointsToCombatant < ActiveRecord::Migration[8.0]
  def change
    add_column :combatants, :max_hit_points, :integer, null: false, default: 1
  end
end
