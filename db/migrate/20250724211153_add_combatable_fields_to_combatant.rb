class AddCombatableFieldsToCombatant < ActiveRecord::Migration[8.0]
  def change
    add_reference :combatants, :combatable, polymorphic: true, null: false
  end
end
