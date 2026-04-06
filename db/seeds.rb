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

  attacks_per_action = case level
  when 1..4 then 1
  when 5..10 then 2
  when 11..19 then 3
  when 20 then 4
  end

  {
    level: level,
    proficiency_bonus: proficiency_bonus,
    grants_ability_score_improvement: fighter_asi_levels.include?(level),
    attacks_per_action: attacks_per_action
  }
end

fighter = PlayerClass.find_by!(name: "Guerreiro")

fighter_progression.each do |attrs|
  progression = ClassLevelProgression.find_or_initialize_by(player_class: fighter, level: attrs[:level])
  progression.assign_attributes(
    proficiency_bonus: attrs[:proficiency_bonus],
    grants_ability_score_improvement: attrs[:grants_ability_score_improvement],
    attacks_per_action: attrs[:attacks_per_action]
  )
  progression.save! if progression.changed?
end

# Fighter subclass modeling: Champion (PHB 2014)
fighter_champion_features = [
  {
    name: "Martial Archetype: Champion",
    slug: "martial-archetype-champion",
    description: "Escolha do arquétipo marcial Champion.",
    feature_type: :subclass,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Fighter 3",
    notes: "Marca a escolha de subclasse e organiza marcos de progressão do Champion.",
    unlocks: [
      {
        level: 3,
        description: "Escolhe Champion como arquétipo marcial."
      }
    ]
  },
  {
    name: "Improved Critical",
    slug: "champion-improved-critical",
    description: "Seus ataques com arma causam acerto crítico com 19 ou 20.",
    feature_type: :subclass_progression,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Champion 3",
    unlocks: [
      {
        level: 3,
        description: "Sua margem de crítico com ataque de arma passa a 19-20.",
        effect_payload: {
          kind: "modifier",
          trigger: "always",
          modifier: "critical_hit_threshold",
          value: 19
        }
      }
    ]
  },
  {
    name: "Remarkable Athlete",
    slug: "champion-remarkable-athlete",
    description: "Adiciona metade da proficiência em testes de FOR, DES e CON sem proficiência e melhora salto em distância.",
    feature_type: :subclass_progression,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Champion 7",
    unlocks: [
      {
        level: 7,
        description: "Ganha bônus atlético parcial e melhora salto em distância."
      }
    ]
  },
  {
    name: "Additional Fighting Style",
    slug: "champion-additional-fighting-style",
    description: "Você pode escolher um segundo Fighting Style entre as opções disponíveis ao Guerreiro.",
    feature_type: :subclass_progression,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Champion 10",
    unlocks: [
      {
        level: 10,
        description: "Escolhe um Fighting Style adicional."
      }
    ]
  },
  {
    name: "Superior Critical",
    slug: "champion-superior-critical",
    description: "Seus ataques com arma causam acerto crítico com 18, 19 ou 20.",
    feature_type: :subclass_progression,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Champion 15",
    notes: "Substitui a faixa de crítico do Improved Critical quando desbloqueado.",
    unlocks: [
      {
        level: 15,
        description: "Sua margem de crítico com ataque de arma passa a 18-20.",
        effect_payload: {
          kind: "modifier",
          trigger: "always",
          modifier: "critical_hit_threshold",
          value: 18
        }
      }
    ]
  },
  {
    name: "Survivor",
    slug: "champion-survivor",
    description: "No início de cada turno, recupera PV iguais a 5 + modificador de CON se tiver metade dos PV ou menos e ao menos 1 PV.",
    feature_type: :subclass_progression,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Champion 18",
    notes: "Recuperação automática por turno; exige suporte de gatilhos de início de turno no motor de combate.",
    unlocks: [
      {
        level: 18,
        description: "Regenera 5 + CON no início do turno sob as condições da habilidade.",
        effect_payload: {
          kind: "heal",
          trigger: "turn_start",
          roll: "5 + constitution_modifier",
          target: "self",
          conditions: {
            current_hp_gt: 0,
            current_hp_lte_max_hp_fraction: 0.5
          }
        }
      }
    ]
  }
]

fighter_champion_features.each do |feature_attrs|
  unlocks = feature_attrs.delete(:unlocks)

  feature = ClassFeature.find_or_initialize_by(player_class: fighter, slug: feature_attrs[:slug])
  feature.assign_attributes(
    feature_attrs.merge(
      grants_spellcasting: false,
      source_book: "PHB 2014"
    )
  )
  feature.save! if feature.changed?

  unlocks.each do |unlock_attrs|
    unlock = ClassFeatureUnlock.find_or_initialize_by(class_feature: feature, level: unlock_attrs[:level])
    unlock.assign_attributes(unlock_attrs)
    unlock.save! if unlock.changed?
  end
end
