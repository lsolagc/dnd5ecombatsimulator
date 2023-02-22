json.extract! base_combatant, :id, :name, :armor_class, :hit_die, :hit_dice_number, :hitpoints, :proficiency_bonus, :strength, :dexterity, :constitution, :intelligence, :wisdom, :charisma, :skills, :created_at, :updated_at
json.url base_combatant_url(base_combatant, format: :json)
