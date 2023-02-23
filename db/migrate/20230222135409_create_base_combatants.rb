class CreateBaseCombatants < ActiveRecord::Migration[7.0]
  def change
    create_table :base_combatants do |t|
      t.string :name
      t.integer :armor_class
      t.integer :hit_die
      t.integer :hit_dice_number
      t.integer :hitpoints
      t.integer :proficiency_bonus, default: 2
      t.integer :strength, default: 10
      t.integer :dexterity, default: 10
      t.integer :constitution, default: 10
      t.integer :intelligence, default: 10
      t.integer :wisdom, default: 10
      t.integer :charisma, default: 10
      t.jsonb :skills

      t.timestamps
    end
  end
end
