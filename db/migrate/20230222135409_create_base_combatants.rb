class CreateBaseCombatants < ActiveRecord::Migration[7.0]
  def change
    create_table :base_combatants do |t|
      t.string :name
      t.integer :armor_class
      t.integer :hit_die
      t.integer :hit_dice_number
      t.integer :hitpoints
      t.integer :proficiency_bonus
      t.integer :strength
      t.integer :dexterity
      t.integer :constitution
      t.integer :intelligence
      t.integer :wisdom
      t.integer :charisma
      t.jsonb :skills

      t.timestamps
    end
  end
end
