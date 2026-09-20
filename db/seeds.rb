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
  next unless progression.new_record? # ClassLevelProgression freezes itself after_find; existing rows are immutable

  progression.assign_attributes(
    proficiency_bonus: attrs[:proficiency_bonus],
    grants_ability_score_improvement: attrs[:grants_ability_score_improvement],
    attacks_per_action: attrs[:attacks_per_action]
  )
  progression.save!
end

# Fighter core features (PHB 2014)
fighter_core_features = [
  {
    name: "Second Wind",
    slug: "second-wind",
    description: "Reserva de estamina usada para se proteger contra danos, recuperando pontos de vida.",
    feature_type: :core,
    action_type: :bonus_action,
    recharge_type: :short_or_long_rest,
    resource_name: "Second Wind",
    source_reference: "Fighter 1",
    unlocks: [
      {
        level: 1,
        uses: 1,
        resource_name: "Second Wind",
        description: "Usa uma ação bônus para recuperar pontos de vida iguais a 1d10 + seu nível de guerreiro.",
        effect_payload: {
          kind: "heal",
          roll: "1d10 + actor_level",
          target: "self"
        }
      }
    ]
  },
  {
    name: "Action Surge",
    slug: "action-surge",
    description: "Força seu limite além do normal por um momento, realizando uma ação adicional no turno.",
    feature_type: :core,
    action_type: :no_action,
    recharge_type: :short_or_long_rest,
    resource_name: "Action Surge",
    source_reference: "Fighter 2",
    unlocks: [
      {
        level: 2,
        uses: 1,
        description: "Realiza uma ação adicional junto com sua ação e possível ação bônus."
      },
      {
        level: 17,
        uses: 2,
        description: "Pode usar Surto de Ação duas vezes entre descansos, mas somente uma vez no mesmo turno."
      }
    ]
  },
  {
    name: "Indomitable",
    slug: "indomitable",
    description: "Permite rolar novamente um teste de resistência que tenha falhado.",
    feature_type: :core,
    action_type: :special,
    recharge_type: :long_rest,
    resource_name: "Indomitable",
    source_reference: "Fighter 9",
    unlocks: [
      {
        level: 9,
        uses: 1,
        description: "Ao falhar um teste de resistência, pode rolar novamente e deve usar o novo resultado. Só pode usar antes de terminar um descanso longo."
      },
      {
        level: 13,
        uses: 2,
        description: "Pode usar Indomável duas vezes entre descansos longos."
      },
      {
        level: 17,
        uses: 3,
        description: "Pode usar Indomável três vezes entre descansos longos."
      }
    ]
  }
]

fighter_core_features.each do |feature_attrs|
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

# Fighter Fighting Style options (PHB 2014) — chosen once at level 1
fighter_fighting_styles = [
  {
    name: "Fighting Style: Archery",
    slug: "fighting-style-archery",
    description: "Ganha +2 de bônus nas jogadas de ataque realizadas com armas de ataque à distância.",
    effect_payload: { kind: "modifier", trigger: "always", modifier: "attack_bonus", value: 2 },
    notes: "Aplicado a todo ataque (não só à distância) porque o motor não distingue arma corpo-a-corpo de arma à distância."
  },
  {
    name: "Fighting Style: Defense",
    slug: "fighting-style-defense",
    description: "Ganha +1 de bônus na Classe de Armadura enquanto estiver usando armadura.",
    effect_payload: { kind: "modifier", trigger: "always", modifier: "armor_class", value: 1 },
    notes: "Aplicado incondicionalmente porque o uso de armadura não é rastreado pelo motor."
  },
  {
    name: "Fighting Style: Dueling",
    slug: "fighting-style-dueling",
    description: "Ganha +2 de bônus nas jogadas de dano ao empunhar uma arma corpo-a-corpo em uma mão e nenhuma outra arma.",
    effect_payload: { kind: "modifier", trigger: "always", modifier: "damage_bonus", value: 2 },
    notes: "Aplicado independente de quantas armas o personagem empunha, pois isso não é rastreado pelo motor."
  },
  {
    name: "Fighting Style: Great Weapon Fighting",
    slug: "fighting-style-great-weapon-fighting",
    description: "Ao rolar 1 ou 2 no dado de dano de um ataque corpo-a-corpo com arma empunhada com duas mãos, pode rolar novamente e usar o novo resultado. A arma deve ter a propriedade duas mãos ou versátil."
  },
  {
    name: "Fighting Style: Protection",
    slug: "fighting-style-protection",
    description: "Ao usar um escudo, pode gastar a reação para impor desvantagem na jogada de ataque de uma criatura que ataque um alvo a até 1,5 metro de você."
  },
  {
    name: "Fighting Style: Two-Weapon Fighting",
    slug: "fighting-style-two-weapon-fighting",
    description: "Ao lutar com duas armas, pode adicionar seu modificador de habilidade de dano na jogada de dano do segundo ataque."
  }
].map do |attrs|
  effect_payload = attrs.delete(:effect_payload)
  notes = attrs.delete(:notes)
  unlock = { level: 1, description: attrs[:description] }
  unlock[:effect_payload] = effect_payload if effect_payload
  unlock[:notes] = notes if notes

  attrs.merge(
    feature_type: :optional,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Fighter 1",
    unlocks: [ unlock ]
  )
end

fighter_fighting_styles.each do |feature_attrs|
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

champion_marker = nil
fighter_champion_features.each do |feature_attrs|
  unlocks = feature_attrs.delete(:unlocks)

  feature = ClassFeature.find_or_initialize_by(player_class: fighter, slug: feature_attrs[:slug])
  feature.assign_attributes(
    feature_attrs.merge(
      grants_spellcasting: false,
      source_book: "PHB 2014",
      subclass_marker: (champion_marker if feature_attrs[:feature_type] == :subclass_progression)
    )
  )
  feature.save! if feature.changed?
  champion_marker = feature if feature_attrs[:feature_type] == :subclass

  unlocks.each do |unlock_attrs|
    unlock = ClassFeatureUnlock.find_or_initialize_by(class_feature: feature, level: unlock_attrs[:level])
    unlock.assign_attributes(unlock_attrs)
    unlock.save! if unlock.changed?
  end
end

# Fighter subclass modeling: Battle Master (PHB 2014)
fighter_battle_master_features = [
  {
    name: "Martial Archetype: Battle Master",
    slug: "martial-archetype-battle-master",
    description: "Escolha do arquétipo marcial Battle Master.",
    feature_type: :subclass,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Fighter 3",
    unlocks: [
      { level: 3, description: "Escolhe Battle Master como arquétipo marcial." }
    ]
  },
  {
    name: "Combat Superiority",
    slug: "battle-master-combat-superiority",
    description: "Aprende manobras abastecidas por dados de superioridade (d8), gastos ao usar e recuperados em um descanso curto ou longo.",
    feature_type: :subclass_progression,
    action_type: :passive,
    recharge_type: :short_or_long_rest,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    unlocks: [
      { level: 3, uses: 4, description: "Aprende três manobras, à sua escolha. Tem quatro dados de superioridade (d8)." },
      { level: 7, uses: 5, description: "Aprende duas manobras adicionais (cinco no total). Ganha mais um dado de superioridade (cinco no total)." },
      { level: 10, uses: 5, description: "Aprende duas manobras adicionais (sete no total)." },
      { level: 15, uses: 6, description: "Aprende duas manobras adicionais (nove no total). Ganha mais um dado de superioridade (seis no total)." }
    ]
  },
  {
    name: "Student of War",
    slug: "battle-master-student-of-war",
    description: "Ganha proficiência com um tipo de ferramenta de artesão, à sua escolha.",
    feature_type: :subclass_progression,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Battle Master 3",
    unlocks: [
      { level: 3, description: "Escolhe uma ferramenta de artesão para ganhar proficiência." }
    ]
  },
  {
    name: "Know Your Enemy",
    slug: "battle-master-know-your-enemy",
    description: "Ao observar ou interagir com uma criatura por ao menos 1 minuto fora de combate, aprende como duas de suas capacidades se comparam às suas.",
    feature_type: :subclass_progression,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Battle Master 7",
    unlocks: [
      { level: 7, description: "Escolhe duas características (FOR, DES, CON, CA, PV atuais, nível total ou nível de guerreiro) para comparar com uma criatura observada." }
    ]
  },
  {
    name: "Improved Combat Superiority",
    slug: "battle-master-improved-combat-superiority",
    description: "Seus dados de superioridade aumentam de tamanho.",
    feature_type: :subclass_progression,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Battle Master 10",
    unlocks: [
      { level: 10, description: "Seus dados de superioridade se tornam d10s." },
      { level: 18, description: "Seus dados de superioridade se tornam d12s." }
    ]
  },
  {
    name: "Relentless",
    slug: "battle-master-relentless",
    description: "Ao rolar iniciativa sem nenhum dado de superioridade restante, recupera um dado de superioridade.",
    feature_type: :subclass_progression,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Battle Master 15",
    unlocks: [
      { level: 15, description: "Recupera um dado de superioridade ao rolar iniciativa sem dados restantes." }
    ]
  },
  {
    name: "Maneuver: Parry",
    slug: "battle-master-maneuver-parry",
    description: "Quando outra criatura causar dano a você com um ataque corpo-a-corpo, usa a reação e gasta um dado de superioridade para reduzir o dano recebido em uma quantidade igual ao número rolado no dado + seu modificador de Destreza.",
    feature_type: :subclass_progression,
    action_type: :reaction,
    recharge_type: :none,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    unlocks: [ { level: 3, description: "Manobra disponível para escolha do Battle Master." } ]
  },
  {
    name: "Maneuver: Menacing Attack",
    slug: "battle-master-maneuver-menacing-attack",
    description: "Ao atingir uma criatura com um ataque com arma, gasta um dado de superioridade para adicioná-lo ao dano; o alvo faz um teste de resistência de Sabedoria ou fica amedrontado até o final do seu próximo turno.",
    feature_type: :subclass_progression,
    action_type: :no_action,
    recharge_type: :none,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    unlocks: [ { level: 3, description: "Manobra disponível para escolha do Battle Master." } ]
  },
  {
    name: "Maneuver: Pushing Attack",
    slug: "battle-master-maneuver-pushing-attack",
    description: "Ao atingir uma criatura com um ataque com arma, gasta um dado de superioridade para adicioná-lo ao dano; se o alvo for Grande ou menor, faz um teste de resistência de Força ou é empurrado até 4,5 metros.",
    feature_type: :subclass_progression,
    action_type: :no_action,
    recharge_type: :none,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    unlocks: [ { level: 3, description: "Manobra disponível para escolha do Battle Master." } ]
  },
  {
    name: "Maneuver: Feinting Attack",
    slug: "battle-master-maneuver-feinting-attack",
    description: "Gasta um dado de superioridade e uma ação bônus para fintar uma criatura a 1,5 metro; ganha vantagem na próxima jogada de ataque contra ela nesse turno e, se acertar, adiciona o dado ao dano.",
    feature_type: :subclass_progression,
    action_type: :bonus_action,
    recharge_type: :none,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    unlocks: [ { level: 3, description: "Manobra disponível para escolha do Battle Master." } ]
  },
  {
    name: "Maneuver: Maneuvering Attack",
    slug: "battle-master-maneuver-maneuvering-attack",
    description: "Ao atingir uma criatura com um ataque com arma, gasta um dado de superioridade para adicioná-lo ao dano e permite que um aliado use a reação para se mover até metade do deslocamento sem provocar ataques de oportunidade do alvo.",
    feature_type: :subclass_progression,
    action_type: :no_action,
    recharge_type: :none,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    unlocks: [ { level: 3, description: "Manobra disponível para escolha do Battle Master." } ]
  },
  {
    name: "Maneuver: Precision Attack",
    slug: "battle-master-maneuver-precision-attack",
    description: "Ao realizar uma jogada de ataque com arma, gasta um dado de superioridade para adicioná-lo à jogada, antes ou depois de rolar, mas antes de aplicar qualquer efeito do ataque.",
    feature_type: :subclass_progression,
    action_type: :no_action,
    recharge_type: :none,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    notes: "Simplificado como dano puro (kind: damage) somado ao ataque, em vez de somar à jogada de acerto: o motor não distingue ajuste de acerto de ajuste de dano nesta manobra. damage_type fixado em bludgeoning (mesmo default do motor em Combatant#damage_type e do fallback de Combat::EffectExecutor) por não haver como propagar dinamicamente o tipo de dano da arma do ator para um effect_payload estático.",
    unlocks: [
      {
        level: 3,
        description: "Manobra disponível para escolha do Battle Master.",
        effect_payload: { kind: "damage", roll: "1d8", target: "target", damage_type: "bludgeoning" }
      }
    ]
  },
  {
    name: "Maneuver: Disarming Attack",
    slug: "battle-master-maneuver-disarming-attack",
    description: "Ao atingir uma criatura com um ataque com arma, gasta um dado de superioridade para adicioná-lo ao dano; o alvo faz um teste de resistência de Força ou deixa cair um item à sua escolha.",
    feature_type: :subclass_progression,
    action_type: :no_action,
    recharge_type: :none,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    notes: "Rider de desarmar não modelado; tratado como dano puro (kind: damage) somado ao ataque. damage_type fixado em bludgeoning (mesmo default do motor), pelo mesmo motivo do Precision Attack.",
    unlocks: [
      {
        level: 3,
        description: "Manobra disponível para escolha do Battle Master.",
        effect_payload: { kind: "damage", roll: "1d8", target: "target", damage_type: "bludgeoning" }
      }
    ]
  },
  {
    name: "Maneuver: Lunging Attack",
    slug: "battle-master-maneuver-lunging-attack",
    description: "Ao atingir uma criatura com um ataque corpo-a-corpo com arma, gasta um dado de superioridade para aumentar o alcance do ataque em 1,5 metro e adicionar o dado ao dano.",
    feature_type: :subclass_progression,
    action_type: :no_action,
    recharge_type: :none,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    notes: "Aumento de alcance não modelado (motor não rastreia posição/distância); tratado como dano puro (kind: damage) somado ao ataque. damage_type fixado em bludgeoning (mesmo default do motor), pelo mesmo motivo do Precision Attack.",
    unlocks: [
      {
        level: 3,
        description: "Manobra disponível para escolha do Battle Master.",
        effect_payload: { kind: "damage", roll: "1d8", target: "target", damage_type: "bludgeoning" }
      }
    ]
  },
  {
    name: "Maneuver: Goading Attack",
    slug: "battle-master-maneuver-goading-attack",
    description: "Ao atingir uma criatura com um ataque com arma, gasta um dado de superioridade para adicioná-lo ao dano; o alvo faz um teste de resistência de Sabedoria ou fica com desvantagem em ataques contra alvos diferentes de você até o final do seu próximo turno.",
    feature_type: :subclass_progression,
    action_type: :no_action,
    recharge_type: :none,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    unlocks: [ { level: 3, description: "Manobra disponível para escolha do Battle Master." } ]
  },
  {
    name: "Maneuver: Sweeping Attack",
    slug: "battle-master-maneuver-sweeping-attack",
    description: "Ao atingir uma criatura com um ataque corpo-a-corpo com arma, gasta um dado de superioridade para causar dano igual ao número rolado a uma segunda criatura a até 1,5 metro do alvo original e dentro do seu alcance.",
    feature_type: :subclass_progression,
    action_type: :no_action,
    recharge_type: :none,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    notes: "Rider de segundo alvo simultâneo não modelado (o motor resolve uma ação de classe contra um único alvo por vez); tratado como dano puro (kind: damage) contra um único alvo. damage_type fixado em bludgeoning (mesmo default do motor), pelo mesmo motivo do Precision Attack.",
    unlocks: [
      {
        level: 3,
        description: "Manobra disponível para escolha do Battle Master.",
        effect_payload: { kind: "damage", roll: "1d8", target: "target", damage_type: "bludgeoning" }
      }
    ]
  },
  {
    name: "Maneuver: Riposte",
    slug: "battle-master-maneuver-riposte",
    description: "Quando uma criatura erra um ataque corpo-a-corpo contra você, usa a reação e gasta um dado de superioridade para realizar um ataque corpo-a-corpo com arma contra ela, adicionando o dado ao dano se acertar.",
    feature_type: :subclass_progression,
    action_type: :reaction,
    recharge_type: :none,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    unlocks: [ { level: 3, description: "Manobra disponível para escolha do Battle Master." } ]
  },
  {
    name: "Maneuver: Trip Attack",
    slug: "battle-master-maneuver-trip-attack",
    description: "Ao atingir uma criatura com um ataque com arma, gasta um dado de superioridade para adicioná-lo ao dano; se o alvo for Grande ou menor, faz um teste de resistência de Força ou fica caído.",
    feature_type: :subclass_progression,
    action_type: :no_action,
    recharge_type: :none,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    unlocks: [ { level: 3, description: "Manobra disponível para escolha do Battle Master." } ]
  },
  {
    name: "Maneuver: Distracting Strike",
    slug: "battle-master-maneuver-distracting-strike",
    description: "Ao atingir uma criatura com um ataque com arma, gasta um dado de superioridade para adicioná-lo ao dano; a próxima jogada de ataque contra o alvo, feita por outra criatura antes do início do seu próximo turno, tem vantagem.",
    feature_type: :subclass_progression,
    action_type: :no_action,
    recharge_type: :none,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    notes: "Rider de vantagem concedida a aliados não modelado (não há sistema de vantagem persistente entre turnos de atores distintos); tratado como dano puro (kind: damage) somado ao ataque. damage_type fixado em bludgeoning (mesmo default do motor), pelo mesmo motivo do Precision Attack.",
    unlocks: [
      {
        level: 3,
        description: "Manobra disponível para escolha do Battle Master.",
        effect_payload: { kind: "damage", roll: "1d8", target: "target", damage_type: "bludgeoning" }
      }
    ]
  },
  {
    name: "Maneuver: Commander's Strike",
    slug: "battle-master-maneuver-commanders-strike",
    description: "Na ação de Ataque, desiste de um dos ataques e usa uma ação bônus para gastar um dado de superioridade e permitir que um aliado use a reação para atacar, adicionando o dado ao dano do aliado.",
    feature_type: :subclass_progression,
    action_type: :bonus_action,
    recharge_type: :none,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    unlocks: [ { level: 3, description: "Manobra disponível para escolha do Battle Master." } ]
  },
  {
    name: "Maneuver: Rally",
    slug: "battle-master-maneuver-rally",
    description: "Usa uma ação bônus e gasta um dado de superioridade para conceder a um aliado pontos de vida temporários iguais ao número rolado no dado + seu modificador de Carisma.",
    feature_type: :subclass_progression,
    action_type: :bonus_action,
    recharge_type: :none,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    unlocks: [ { level: 3, description: "Manobra disponível para escolha do Battle Master." } ]
  },
  {
    name: "Maneuver: Evasive Footwork",
    slug: "battle-master-maneuver-evasive-footwork",
    description: "Ao se mover, pode gastar um dado de superioridade, rolar o dado e adicionar o resultado à sua CA até terminar o deslocamento.",
    feature_type: :subclass_progression,
    action_type: :no_action,
    recharge_type: :none,
    resource_name: "Superiority Dice",
    source_reference: "Battle Master 3",
    unlocks: [ { level: 3, description: "Manobra disponível para escolha do Battle Master." } ]
  }
]

battle_master_marker = nil
fighter_battle_master_features.each do |feature_attrs|
  unlocks = feature_attrs.delete(:unlocks)

  feature = ClassFeature.find_or_initialize_by(player_class: fighter, slug: feature_attrs[:slug])
  feature.assign_attributes(
    feature_attrs.merge(
      grants_spellcasting: false,
      source_book: "PHB 2014",
      subclass_marker: (battle_master_marker if feature_attrs[:feature_type] == :subclass_progression)
    )
  )
  feature.save! if feature.changed?
  battle_master_marker = feature if feature_attrs[:feature_type] == :subclass

  unlocks.each do |unlock_attrs|
    unlock = ClassFeatureUnlock.find_or_initialize_by(class_feature: feature, level: unlock_attrs[:level])
    unlock.assign_attributes(unlock_attrs)
    unlock.save! if unlock.changed?
  end
end

# Spell catalog (minimal, evocation/abjuration focus for Eldritch Knight)
spells = [
  {
    name: "Fire Bolt",
    slug: "fire-bolt",
    level: 0,
    school: "evocation",
    description: "Trote de fogo lançado como ataque de magia à distância.",
    effect_payload: { kind: "damage", roll: "1d10", target: "target", damage_type: "fire", attack: "spell" }
  },
  {
    name: "Ray of Frost",
    slug: "ray-of-frost",
    level: 0,
    school: "evocation",
    description: "Um raio de luz azul-branca gélida atinge uma criatura.",
    effect_payload: { kind: "damage", roll: "1d8", target: "target", damage_type: "cold", attack: "spell" }
  },
  {
    name: "Chromatic Orb",
    slug: "chromatic-orb",
    level: 1,
    school: "evocation",
    description: "Arremessa uma esfera de energia contra uma criatura em um ataque de magia à distância.",
    effect_payload: { kind: "damage", roll: "3d8", target: "target", damage_type: "force", attack: "spell" }
  },
  {
    name: "Shield",
    slug: "shield",
    level: 1,
    school: "abjuration",
    description: "Reação que concede +5 de bônus na CA até o início do seu próximo turno."
  },
  {
    name: "Scorching Ray",
    slug: "scorching-ray",
    level: 2,
    school: "evocation",
    description: "Cria três raios de fogo; todos podem ser direcionados ao mesmo alvo.",
    notes: "Simplificado para um único alvo somando o dano dos três raios (6d6) sob UMA só jogada de ataque de magia (RAW: um ataque por raio, 2d6 cada); mesma média, mas tudo-ou-nada; o motor de combate ainda não modela múltiplos alvos por magia.",
    effect_payload: { kind: "damage", roll: "6d6", target: "target", damage_type: "fire", attack: "spell" }
  },
  {
    name: "Fireball",
    slug: "fireball",
    level: 3,
    school: "evocation",
    description: "Uma explosão de fogo que afeta uma área.",
    notes: "Simplificado para um único alvo (8d6); a magia original afeta uma área e não é modelada como AoE ainda.",
    effect_payload: { kind: "damage", roll: "8d6", target: "target", damage_type: "fire", save: { ability: "dexterity", dc: "spell", on_success: "half" } }
  },
  {
    name: "Stoneskin",
    slug: "stoneskin",
    level: 4,
    school: "abjuration",
    description: "Concede resistência a dano de armas não-mágicas para uma criatura tocada."
  }
]

spells.each do |spell_attrs|
  spell = Spell.find_or_initialize_by(slug: spell_attrs[:slug])
  spell.assign_attributes(spell_attrs)
  spell.save! if spell.changed?
end

# Fighter subclass modeling: Eldritch Knight (PHB 2014)
fighter_eldritch_knight_features = [
  {
    name: "Martial Archetype: Eldritch Knight",
    slug: "martial-archetype-eldritch-knight",
    description: "Escolha do arquétipo marcial Eldritch Knight.",
    feature_type: :subclass,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Fighter 3",
    unlocks: [
      { level: 3, description: "Escolhe Eldritch Knight como arquétipo marcial." }
    ]
  },
  {
    name: "Spellcasting",
    slug: "eldritch-knight-spellcasting",
    description: "Amplia seu poderio marcial com a habilidade de conjurar magias de mago, focadas em abjuração e evocação.",
    feature_type: :subclass_progression,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Eldritch Knight 3",
    grants_spellcasting: true,
    spellcasting_ability: :intelligence,
    unlocks: [
      { level: 3, description: "Ganha acesso a truques e magias de 1º nível de mago, restritas a abjuração e evocação (algumas magias de qualquer escola nos níveis 8, 14 e 20)." }
    ]
  },
  {
    name: "Weapon Bond",
    slug: "eldritch-knight-weapon-bond",
    description: "Cria um vínculo mágico com até duas armas; não pode ser desarmado delas a menos que incapacitado, e pode invocar uma delas com uma ação bônus.",
    feature_type: :subclass_progression,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Eldritch Knight 3",
    unlocks: [
      { level: 3, description: "Realiza o ritual de vínculo com até duas armas." }
    ]
  },
  {
    name: "War Magic",
    slug: "eldritch-knight-war-magic",
    description: "Ao usar a ação para conjurar um truque, pode realizar um ataque com arma com uma ação bônus.",
    feature_type: :subclass_progression,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Eldritch Knight 7",
    notes: "Implementado em CombatSimulatorService: um ataque bônus com arma dispara sempre que a ação normal do turno for conjurar um truque (cast_spell com spell.cantrip? true), sem consumir recurso. Não encadeia com Action Surge nem com o próprio ataque bônus.",
    unlocks: [
      { level: 7, description: "Conjurar um truque como ação permite um ataque com arma como ação bônus." }
    ]
  },
  {
    name: "Eldritch Strike",
    slug: "eldritch-knight-eldritch-strike",
    description: "Ao atingir uma criatura com um ataque com arma, ela fica com desvantagem no próximo teste de resistência contra uma magia sua até o final do seu próximo turno.",
    feature_type: :subclass_progression,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Eldritch Knight 10",
    notes: "Simplificação deliberada: o RAW impõe a desvantagem \"até o final do seu próximo turno\", mas o motor não tem nenhum conceito de duração/expiração por turno. Implementado como consumo único (last-hit-wins se dois atores diferentes acertarem o mesmo alvo): o primeiro saving throw do alvo contra uma magia do MESMO ator que o atingiu recebe disadvantage_on_save, e a marca pendente é removida na hora, independentemente de quantos turnos realmente passaram.",
    unlocks: [
      { level: 10, description: "Um ataque com arma impõe desvantagem no próximo teste de resistência contra suas magias." }
    ]
  },
  {
    name: "Arcane Charge",
    slug: "eldritch-knight-arcane-charge",
    description: "Ao usar Surto de Ação, pode se teletransportar até 9 metros para um espaço desocupado que possa ver.",
    feature_type: :subclass_progression,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Eldritch Knight 15",
    unlocks: [
      { level: 15, description: "Teletransporte de até 9 metros ao usar Surto de Ação." }
    ]
  },
  {
    name: "Improved War Magic",
    slug: "eldritch-knight-improved-war-magic",
    description: "Ao usar a ação para conjurar qualquer magia, pode realizar um ataque com arma com uma ação bônus.",
    feature_type: :subclass_progression,
    action_type: :passive,
    recharge_type: :none,
    source_reference: "Eldritch Knight 18",
    notes: "Implementado em CombatSimulatorService: mesma regra do War Magic, mas sem restringir a truque — qualquer cast_spell na ação normal do turno dispara o ataque bônus.",
    unlocks: [
      { level: 18, description: "Conjurar qualquer magia como ação permite um ataque com arma como ação bônus." }
    ]
  }
]

eldritch_knight_marker = nil
fighter_eldritch_knight_features.each do |feature_attrs|
  unlocks = feature_attrs.delete(:unlocks)
  grants_spellcasting = feature_attrs.delete(:grants_spellcasting) || false

  feature = ClassFeature.find_or_initialize_by(player_class: fighter, slug: feature_attrs[:slug])
  feature.assign_attributes(
    feature_attrs.merge(
      grants_spellcasting: grants_spellcasting,
      source_book: "PHB 2014",
      subclass_marker: (eldritch_knight_marker if feature_attrs[:feature_type] == :subclass_progression)
    )
  )
  feature.save! if feature.changed?
  eldritch_knight_marker = feature if feature_attrs[:feature_type] == :subclass

  unlocks.each do |unlock_attrs|
    unlock = ClassFeatureUnlock.find_or_initialize_by(class_feature: feature, level: unlock_attrs[:level])
    unlock.assign_attributes(unlock_attrs)
    unlock.save! if unlock.changed?
  end
end

# Eldritch Knight spell slot progression (PHB 2014, "Conjuração de Cavaleiro Arcano")
eldritch_knight_spellcasting = ClassFeature.find_by!(player_class: fighter, slug: "eldritch-knight-spellcasting")

eldritch_knight_slot_table = [
  { level: 3,  cantrips_known: 2, spells_known: 3,  slots: [ 2, 0, 0, 0 ] },
  { level: 4,  cantrips_known: 2, spells_known: 4,  slots: [ 3, 0, 0, 0 ] },
  { level: 5,  cantrips_known: 2, spells_known: 4,  slots: [ 3, 0, 0, 0 ] },
  { level: 6,  cantrips_known: 2, spells_known: 4,  slots: [ 3, 0, 0, 0 ] },
  { level: 7,  cantrips_known: 2, spells_known: 5,  slots: [ 4, 2, 0, 0 ] },
  { level: 8,  cantrips_known: 2, spells_known: 6,  slots: [ 4, 2, 0, 0 ] },
  { level: 9,  cantrips_known: 2, spells_known: 6,  slots: [ 4, 2, 0, 0 ] },
  { level: 10, cantrips_known: 3, spells_known: 7,  slots: [ 4, 3, 0, 0 ] },
  { level: 11, cantrips_known: 3, spells_known: 8,  slots: [ 4, 3, 0, 0 ] },
  { level: 12, cantrips_known: 3, spells_known: 8,  slots: [ 4, 3, 0, 0 ] },
  { level: 13, cantrips_known: 3, spells_known: 9,  slots: [ 4, 3, 2, 0 ] },
  { level: 14, cantrips_known: 3, spells_known: 10, slots: [ 4, 3, 2, 0 ] },
  { level: 15, cantrips_known: 3, spells_known: 10, slots: [ 4, 3, 2, 0 ] },
  { level: 16, cantrips_known: 3, spells_known: 11, slots: [ 4, 3, 3, 0 ] },
  { level: 17, cantrips_known: 3, spells_known: 11, slots: [ 4, 3, 3, 0 ] },
  { level: 18, cantrips_known: 3, spells_known: 11, slots: [ 4, 3, 3, 0 ] },
  { level: 19, cantrips_known: 3, spells_known: 12, slots: [ 4, 3, 3, 1 ] },
  { level: 20, cantrips_known: 3, spells_known: 13, slots: [ 4, 3, 3, 1 ] }
]

eldritch_knight_slot_table.each do |attrs|
  progression = SpellSlotProgression.find_or_initialize_by(class_feature: eldritch_knight_spellcasting, level: attrs[:level])
  progression.assign_attributes(
    cantrips_known: attrs[:cantrips_known],
    spells_known: attrs[:spells_known],
    spell_slots_1: attrs[:slots][0],
    spell_slots_2: attrs[:slots][1],
    spell_slots_3: attrs[:slots][2],
    spell_slots_4: attrs[:slots][3]
  )
  progression.save! if progression.changed?
end
