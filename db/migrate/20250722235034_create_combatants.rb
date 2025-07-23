class CreateCombatants < ActiveRecord::Migration[8.0]
  def conditions_and_damages_hash
    {
      conditions: {
        blindness: false,
        charm: false,
        deafness: false,
        fear: false,
        grapple: false,
        incapacitation: false,
        invisibility: false,
        paralysis: false,
        petrification: false,
        poisoning: false,
        prone: false,
        restraint: false,
        stun: false,
        unconsciousness: false,
        exhaustion: false
      },
      damage_types: {
        acid: false,
        bludgeoning: false,
        cold: false,
        fire: false,
        force: false,
        lightning: false,
        necrotic: false,
        piercing: false,
        poison: false,
        psychic: false,
        radiant: false,
        slashing: false,
        thunder: false
      }
    }
  end

  def change
    create_table :combatants do |t|
      t.integer :armor_class, null: false, default: 10
      t.integer :strength, null: false, default: 10
      t.integer :dexterity, null: false, default: 10
      t.integer :constitution, null: false, default: 10
      t.integer :intelligence, null: false, default: 10
      t.integer :wisdom, null: false, default: 10
      t.integer :charisma, null: false, default: 10
      t.integer :speed, null: false, default: 30
      t.integer :proficiency_bonus, null: false, default: 2
      t.jsonb :vulnerabilities, default: conditions_and_damages_hash
      t.jsonb :resistances, default: conditions_and_damages_hash
      t.jsonb :immunities, default: conditions_and_damages_hash
      t.timestamps
    end
  end
end
