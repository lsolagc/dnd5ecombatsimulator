# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

player_classes = [
  {
    name: "Bárbaro",
    hit_die: :d12,
    description: "Guerreiros selvagens que canalizam sua fúria em combate.",
    spellcasting_modifier: nil
  },
  {
    name: "Bardo",
    hit_die: :d8,
    description: "Artistas mágicos versáteis, mestres em inspirar aliados.",
    spellcasting_modifier: :charisma
  },
  {
    name: "Bruxo",
    hit_die: :d8,
    description: "Usuários de magia que fazem pactos com entidades poderosas.",
    spellcasting_modifier: :charisma
  },
  {
    name: "Clérigo",
    hit_die: :d8,
    description: "Servos divinos que canalizam o poder de seus deuses.",
    spellcasting_modifier: :wisdom
  },
  {
    name: "Druida",
    hit_die: :d8,
    description: "Guardião da natureza e mestre da transformação.",
    spellcasting_modifier: :wisdom
  },
  {
    name: "Feiticeiro",
    hit_die: :d6,
    description: "Magos inatos que manipulam magia bruta.",
    spellcasting_modifier: :charisma
  },
  {
    name: "Guerreiro",
    hit_die: :d10,
    description: "Combatentes versáteis e mestres em armas.",
    spellcasting_modifier: nil
  },
  {
    name: "Ladino",
    hit_die: :d8,
    description: "Especialistas em furtividade, truques e ataques precisos.",
    spellcasting_modifier: nil
  },
  {
    name: "Mago",
    hit_die: :d6,
    description: "Estudiosos da magia arcana e do conhecimento.",
    spellcasting_modifier: :intelligence
  },
  {
    name: "Monge",
    hit_die: :d8,
    description: "Mestres das artes marciais e do ki.",
    spellcasting_modifier: nil
  },
  {
    name: "Paladino",
    hit_die: :d10,
    description: "Guerreiros sagrados guiados por um juramento.",
    spellcasting_modifier: :charisma
  },
  {
    name: "Patrulheiro",
    hit_die: :d10,
    description: "Exploradores e caçadores especialistas em terrenos selvagens.",
    spellcasting_modifier: :wisdom
  }
]

player_classes.each do |attrs|
  PlayerClass.find_or_create_by!(name: attrs[:name]) do |pc|
    pc.hit_die = attrs[:hit_die]
    pc.description = attrs[:description]
    pc.spellcasting_modifier = attrs[:spellcasting_modifier]
  end
end

# Fighter class progression (D&D 5e)
# ASI at levels 4, 6, 8, 12, 14, 16, 19 (Fighter gets more ASIs than most classes)
fighter_asi_levels = [ 4, 6, 8, 12, 14, 16, 19 ]

fighter_progression = (1..20).map do |level|
  proficiency_bonus = case level
  when 1..4  then 2
  when 5..8  then 3
  when 9..12 then 4
  when 13..16 then 5
  when 17..20 then 6
  end

  {
    level: level,
    proficiency_bonus: proficiency_bonus,
    grants_ability_score_improvement: fighter_asi_levels.include?(level)
  }
end

fighter = PlayerClass.find_by!(name: "Guerreiro")

fighter_progression.each do |attrs|
  ClassLevelProgression.find_or_create_by!(player_class: fighter, level: attrs[:level]) do |clp|
    clp.proficiency_bonus = attrs[:proficiency_bonus]
    clp.grants_ability_score_improvement = attrs[:grants_ability_score_improvement]
  end
end
