class AddBasicAttackFieldsToCombatant < ActiveRecord::Migration[8.0]
  def change
    add_column :combatants, :attack_bonus, :integer, null: false, default: 0
    add_column :combatants, :damage_dice, :string, null: false, default: "1d4"
    add_column :combatants, :damage_type, :string, null: false, default: "bludgeoning"
  end
end
