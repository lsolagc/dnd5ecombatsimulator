require "test_helper"
require "minitest/mock"

# Pass 2 of the gambits: every turn action the simulator can take is reachable through a gambit, on the
# real content of db/seeds (loaded inside each test's transaction), plus the conditions added in pass 2
# and Action Surge as a gambit action.
class CombatSimulatorGambitCoverageTest < ActiveSupport::TestCase
  # One case per turn action of the inventory (.okf/architecture/gambits-decisions.md, Pass 2). The
  # Battle Master learns the maneuver in place of Parry (3 known at level 3). Scorching Ray (level 2) and
  # Fireball (level 3) need slots no seed character has: the Cavaleiro Arcano is raised to level 13
  # (slots 4/3/2, 9 spells known), within PlayerCharacterSpell's limits.
  INVENTORY = [
    { item: "Ataque", actor: "Campeão", rule: {}, action: { type: :attack } },
    { item: "Second Wind", actor: "Campeão", rule: { target: :self, feature: "second-wind" },
      action: { type: :class_feature, feature_slug: "second-wind" } },
    { item: "Action Surge", actor: "Campeão", rule: { target: :self, feature: "action-surge" }, action: { type: :action_surge } },
    *{ "Precision Attack" => "precision-attack", "Disarming Attack" => "disarming-attack", "Lunging Attack" => "lunging-attack",
       "Sweeping Attack" => "sweeping-attack", "Distracting Strike" => "distracting-strike" }.map do |name, slug|
      { item: name, actor: "Mestre de Batalha", maneuver: "battle-master-maneuver-#{slug}",
        rule: { feature: "battle-master-maneuver-#{slug}" }, action: { type: :attack, riders: [ { feature_slug: "battle-master-maneuver-#{slug}", feature_name: "Maneuver: #{name}" } ] } }
    end,
    *%w[fire-bolt ray-of-frost chromatic-orb].map do |slug|
      { item: slug, actor: "Cavaleiro Arcano", rule: { spell: slug }, action: { type: :cast_spell, spell_slug: slug } }
    end,
    *%w[scorching-ray fireball].map do |slug|
      { item: slug, actor: "Cavaleiro Arcano", level: 13, spell: slug, rule: { spell: slug }, action: { type: :cast_spell, spell_slug: slug } }
    end
  ].freeze

  setup do
    SeedData.load_all
    @hit_points = {}
  end

  INVENTORY.each do |entry|
    item, actor, action = entry.values_at(:item, :actor, :action)

    test "inventory: a single gambit fires #{item}" do
      character = seed_character(actor, level: entry[:level])
      learn_maneuver(character, entry[:maneuver]) if entry[:maneuver]
      character.player_character_spells.find_or_create_by!(spell: Spell.find_by!(slug: entry[:spell])) if entry[:spell]
      add_rule(character, position: 1, **entry[:rule])
      enemy = seed_character(actor == "Campeão" ? "Mestre de Batalha" : "Campeão")

      turn = actor_turns(character, simulator(party_one: [ character ], party_two: [ enemy ], seed: 1, max_rounds: 1).call).first

      assert_equal action, turn[:action].slice(:type, :riders, :feature_slug, :spell_slug), "#{item}: wrong action"
      assert_equal 1, turn.dig(:gambit, :position), "#{item}: not fired by the rule"
      assert_equal [ enemy.combatant.id ], turn[:results].map { |result| result[:target_id] }.uniq if action[:type] == :attack
    end
  end

  test "hp_above fires only strictly above the threshold" do
    actor = seed_character("Campeão")
    enemy = seed_character("Mestre de Batalha", hit_points: 10)
    gambit = add_rule(actor, position: 1, condition: :hp_above, condition_value: 50)
    enemy.max_hit_points = 20 # 10: exactly 50%
    encounter = prepared_encounter(party_one: [ actor ], party_two: [ enemy ])
    actor, enemy = participant_of(encounter, actor), participant_of(encounter, enemy)
    policy = Combat::GambitPolicy.new(encounter:)

    assert_nil policy.target(actor:, gambit:)

    enemy.heal(1)
    assert_equal enemy, policy.target(actor:, gambit:)

    # 63/125 = 50.4%: above 50% even though it rounds to 50.
    enemy.character.max_hit_points = 125
    enemy.heal(52)
    assert_equal enemy, policy.target(actor:, gambit:)
  end

  test "highest_hp picks the healthiest enemy, ties going to initiative order" do
    actor = seed_character("Cavaleiro Arcano")
    first_in_party, second_in_party = seed_character("Campeão", hit_points: 30), seed_character("Mestre de Batalha", hit_points: 30)
    gambit = add_rule(actor, position: 1, condition: :highest_hp)
    encounter = prepared_encounter(party_one: [ actor ], party_two: [ first_in_party, second_in_party ],
                                   initiative_order: [ second_in_party, actor, first_in_party ])
    actor, first_in_party, second_in_party = [ actor, first_in_party, second_in_party ].map { |character| participant_of(encounter, character) }
    policy = Combat::GambitPolicy.new(encounter:)

    assert_equal second_in_party, policy.target(actor:, gambit:), "a tie goes to the first in initiative order"

    second_in_party.take_damage(amount: 1, damage_type: "force")
    assert_equal first_in_party, policy.target(actor:, gambit:)
  end

  test "marked and unmarked look at marks the actor would use: someone else's, never its own" do
    actor = seed_character("Mestre de Batalha")
    ally = seed_character("Cavaleiro Arcano")
    first, second = seed_character("Campeão"), player_characters(:aragorn) # the seeds hold only three characters
    marked = add_rule(actor, position: 1, condition: :marked)
    unmarked = add_rule(actor, position: 2, condition: :unmarked)
    encounter = prepared_encounter(party_one: [ actor, ally ], party_two: [ first, second ], initiative_order: [ actor, ally, first, second ])
    actor, ally, first, second = [ actor, ally, first, second ].map { |character| participant_of(encounter, character) }
    policy = Combat::GambitPolicy.new(encounter:)
    mark = ->(target, source) { target.add_status(Combat::Status.new(kind: "next_attack_advantage", source:, ends: "source_turn_start")) }

    mark.(first, actor) # the actor's own mark: its next attack would not get advantage from it
    assert_nil policy.target(actor:, gambit: marked)
    assert_equal first, policy.target(actor:, gambit: unmarked)

    mark.(second, ally)
    assert_equal second, policy.target(actor:, gambit: marked)
    assert_equal first, policy.target(actor:, gambit: unmarked)

    mark.(first, ally)
    assert_equal first, policy.target(actor:, gambit: marked)
    assert_nil policy.target(actor:, gambit: unmarked)
  end

  test "resource_at_least measures the rule's own resource: feature uses, the superiority pool, spell slots" do
    enemy = player_characters(:aragorn) # the Campeão is one of the actors
    cases = {
      "Second Wind uses" => [ seed_character("Campeão"), { target: :self, feature: "second-wind" }, 1 ],
      "superiority dice" => [ seed_character("Mestre de Batalha"), { feature: "battle-master-maneuver-precision-attack" }, 4 ],
      "level 1 slots" => [ seed_character("Cavaleiro Arcano"), { spell: "chromatic-orb" }, 2 ]
    }

    cases.each do |resource, (actor, rule, remaining)|
      at_least = ->(value) do
        actor.gambits.reset
        add_rule(actor, position: 1, condition: :resource_at_least, condition_value: value, **rule)
        encounter = prepared_encounter(party_one: [ actor ], party_two: [ enemy ])
        fighter = participant_of(encounter, actor)
        Combat::GambitPolicy.new(encounter:).choose(actor: fighter, options: fighter.action_options)
      end

      assert at_least.(remaining), "#{resource}: #{remaining} left must satisfy ≥ #{remaining}"
      assert_equal 1, at_least.(remaining).gambit.position
      assert_nil at_least.(remaining + 1), "#{resource}: #{remaining} left must not satisfy ≥ #{remaining + 1}"
    end
  end

  test "resource_at_least on a spell counts only the slots of the spell's own level" do
    # Level 13: slots 4/3/2, so only the spell's level (3: two slots) separates the thresholds below.
    knight = seed_character("Cavaleiro Arcano", level: 13)
    knight.player_character_spells.create!(spell: Spell.find_by!(slug: "fireball"))
    knight.player_character_spells.create!(spell: Spell.find_by!(slug: "scorching-ray"))
    assert_equal({ 1 => 4, 2 => 3, 3 => 2, 4 => 0 }, knight.spell_slots)
    encounter = prepared_encounter(party_one: [ knight ], party_two: [ player_characters(:aragorn) ])
    caster = participant_of(encounter, knight)
    fires = lambda do |spell, value|
      knight.gambits.reset
      add_rule(knight, position: 1, condition: :resource_at_least, condition_value: value, spell:)
      Combat::GambitPolicy.new(encounter:).choose(actor: caster, options: caster.action_options).present?
    end

    assert fires.("fireball", 2)
    assert_not fires.("fireball", 3), "3 slots of another level must not count for a level 3 spell"

    caster.available_spell_slots[2] = 1 # spending level 2 slots changes only the level 2 rule
    assert fires.("fireball", 2)
    assert_not fires.("scorching-ray", 2)
    assert fires.("scorching-ray", 1)
  end

  test "resource_at_least counts unlimited uses as available and picks the first candidate in initiative order" do
    actor = seed_character("Campeão")
    first, second = seed_character("Mestre de Batalha"), seed_character("Cavaleiro Arcano")
    encounter = prepared_encounter(party_one: [ actor ], party_two: [ first, second ], initiative_order: [ second, actor, first ])
    actor, second = participant_of(encounter, actor), participant_of(encounter, second)
    gambit = add_rule(actor.character, position: 1, target: :enemy, condition: :resource_at_least, condition_value: 20,
                                       feature: "battle-master-maneuver-precision-attack")
    policy = Combat::GambitPolicy.new(encounter:)
    unlimited = Combat::ActionOption.new(type: :class_feature, class_feature: seed_feature("battle-master-maneuver-precision-attack")) # no uses_remaining

    chosen = policy.choose(actor:, options: [ unlimited ])
    assert chosen, "unlimited uses must satisfy ≥ 20"
    assert_equal second, chosen.target
    assert_equal second, policy.target(actor:, gambit:)
  end

  test "resource_at_least on an Action Surge rule counts its uses" do
    champion = seed_character("Campeão") # level 5: one Action Surge
    encounter = prepared_encounter(party_one: [ champion ], party_two: [ seed_character("Mestre de Batalha") ])
    fighter = participant_of(encounter, champion)
    fires = lambda do |value|
      champion.gambits.reset
      add_rule(champion, position: 1, target: :self, condition: :resource_at_least, condition_value: value, feature: "action-surge")
      Combat::GambitPolicy.new(encounter:).choose(actor: fighter, options: fighter.action_options)&.type
    end

    assert_equal 1, uses_left(encounter, champion, "action-surge")
    assert_equal :action_surge, fires.(1)
    assert_nil fires.(2)
  end

  test "Action Surge through a gambit: one use, a marker, then the normal action and the extra one" do
    actor = seed_character("Campeão")
    add_rule(actor, position: 1, target: :self, feature: "action-surge")
    add_rule(actor, position: 2)
    encounter, turns = one_turn(actor)

    assert_equal [ [ :action_surge, 1, false ], [ :attack, 2, false ], [ :attack, 2, true ] ],
                 turns.map { |turn| [ turn.action[:type], turn.gambit[:position], turn.extra ] }
    assert_equal [], turns.first.results
    assert_equal 0, uses_left(encounter, actor, "action-surge")
  end

  test "Action Surge through a gambit spends exactly one use and never chains, even with two uses" do
    actor = seed_character("Campeão", level: 17)
    add_rule(actor, position: 1, target: :self, feature: "action-surge")
    add_rule(actor, position: 2)
    encounter, turns = one_turn(actor)

    assert_equal 2, actor.feature_unlocks.find { |unlock| unlock.class_feature == seed_feature("action-surge") }.uses, "two uses at level 17"
    assert_equal [ :action_surge, :attack, :attack ], turns.map { |turn| turn.action[:type] }
    assert_equal 1, uses_left(encounter, actor, "action-surge")
  end

  test "nothing happens after the fight ends inside an Action Surge: no extra action, no War Magic bonus" do
    # Level 18: Improved War Magic (a bonus attack after any spell) and level 3 slots. Fireball always
    # deals damage (half on a save), so it kills the 1 HP enemy: the surge's first action ends the fight.
    knight = seed_character("Cavaleiro Arcano", level: 18)
    knight.player_character_spells.create!(spell: Spell.find_by!(slug: "fireball"))
    add_rule(knight, position: 1, target: :self, feature: "action-surge")
    add_rule(knight, position: 2, spell: "fireball")
    add_rule(knight, position: 3, target: :self, feature: "second-wind")
    enemy = seed_character("Campeão", hit_points: 1)
    encounter = prepared_encounter(party_one: [ knight ], party_two: [ enemy ])

    turns = build_turn_executor(encounter).take_turn(participant_of(encounter, knight), round: 1, turn: 1)

    assert participant_of(encounter, enemy).dead?
    assert_equal [ [ :action_surge, 1 ], [ :cast_spell, 2 ] ], turns.map { |turn| [ turn.action[:type], turn.gambit[:position] ] }
    assert_equal 1, uses_left(encounter, knight, "second-wind")
  end

  test "inside an Action Surge each evaluation may stand idle, and only the extra one is marked extra" do
    actor = seed_character("Campeão")
    add_rule(actor, position: 1, target: :self, feature: "action-surge")
    _, turns = one_turn(actor)

    assert_equal [ [ :action_surge, false ], [ :idle, false ], [ :idle, true ] ], turns.map { |turn| [ turn.action[:type], turn.extra ] }
    assert_equal [ { position: 1, rule: "Self: qualquer → Action Surge" }, "nenhum aplicável: parado", "nenhum aplicável: parado" ],
                 turns.map(&:gambit)
  end

  test "every decision entry logs the gambit behind it; the War Magic bonus inherits its spell's, passives log none" do
    knight = seed_character("Cavaleiro Arcano", level: 18) # Improved War Magic: a bonus attack after any spell
    add_rule(knight, position: 1, target: :self, feature: "action-surge")
    add_rule(knight, position: 2, spell: "fire-bolt")
    idler = seed_character("Mestre de Batalha")
    add_rule(idler, position: 1, condition: :hp_below, condition_value: 1) # never fires on a living enemy
    champion = seed_character("Campeão", level: 18) # no gambits: random, with Action Surge
    @hit_points[champion.combatant.id] = champion.max_hit_points / 2 # Survivor heals at the start of its turn

    entries = simulator(party_one: [ knight, idler ], party_two: [ champion ], seed: 1, max_rounds: 1).call[:round_log]
      .flat_map { |round| round[:turns] }
    logged = ->(actor) { entries.select { |turn| turn[:actor_id] == actor.combatant.id }.map { |turn| [ turn.dig(:action, :type), turn.slice(:bonus, :extra, :gambit) ] } }

    surge = { position: 1, rule: "Self: qualquer → Action Surge" }
    bolt = { position: 2, rule: "Inimigo: qualquer → Fire Bolt" }
    assert_equal [ [ :action_surge, { gambit: surge } ], [ :cast_spell, { gambit: bolt } ], [ :attack, { bonus: true, gambit: bolt } ],
                   [ :cast_spell, { extra: true, gambit: bolt } ] ], logged.(knight)
    assert_equal [ [ :idle, { gambit: "nenhum aplicável: parado" } ] ], logged.(idler)
    champion_entries = logged.(champion)
    assert_equal [ :turn_passive, {} ], champion_entries.first
    assert_equal [ {}, { gambit: "aleatório" }, { extra: true, gambit: "aleatório" } ], champion_entries.map(&:second).uniq
  end

  test "a gambit-driven actor with no Action Surge rule never surges, whether it acts or stands idle" do
    { "acting" => {}, "idle" => { condition: :hp_below, condition_value: 1 } }.each do |scenario, rule|
      actor = seed_character("Campeão")
      actor.gambits.reset
      add_rule(actor, position: 1, **rule)
      simulation = simulator(party_one: [ actor ], party_two: [ seed_character("Mestre de Batalha") ], seed: 1, max_rounds: 3)

      turns = actor_turns(actor, simulation.call, extras: true)

      assert_equal 3, turns.size, scenario
      assert turns.none? { |turn| turn[:extra] || turn.dig(:action, :type) == :action_surge }, "#{scenario}: surged without a rule"
      assert_equal 1, uses_left(simulation, actor, "action-surge"), scenario
    end
  end

  test "War Magic for a gambit-driven actor hits the spell's target, else the first living enemy in initiative order" do
    actor = seed_character("Cavaleiro Arcano", level: 7)
    first, second = seed_character("Campeão"), seed_character("Mestre de Batalha")
    gambit = add_rule(actor, position: 1, spell: "fire-bolt")
    encounter = prepared_encounter(party_one: [ actor ], party_two: [ first, second ], initiative_order: [ first, actor, second ])
    rng = Random.new(1)
    executor = build_turn_executor(encounter, rng:)
    actor, second = participant_of(encounter, actor), participant_of(encounter, second)
    option = actor.action_options.find { |action| action.spell&.slug == "fire-bolt" }
    bonus_targets = lambda do
      executor.war_magic_turn(actor:, option: option.with(target: second, gambit:), round: 1, turn: 1).results
        .map { |attack| attack[:target_id] }
    end

    assert_equal [ second.id ], bonus_targets.call, "one attack, on the spell's target"

    second.take_damage(amount: second.current_hit_points, damage_type: "force")
    assert second.dead?
    assert_equal [ first.combatant.id ], bonus_targets.call
    assert_equal Marshal.dump(Random.new(1)), Marshal.dump(rng)
  end

  test "War Magic's fallback with several enemies left: the first living one in initiative order" do
    knight = seed_character("Cavaleiro Arcano", level: 7)
    spell_target, party_first, initiative_first, party_last =
      seed_character("Campeão"), seed_character("Mestre de Batalha"), player_characters(:aragorn), player_characters(:aragorn_copy)
    enemies = [ spell_target, party_first, initiative_first, party_last ]
    enemies.each { |enemy| @hit_points[enemy.combatant.id] = 1000 }
    @hit_points[spell_target.combatant.id] = 0 # the spell killed its own target, leaving three enemies alive
    gambit = add_rule(knight, position: 1, spell: "fire-bolt")
    encounter = prepared_encounter(party_one: [ knight ], party_two: enemies,
                                   initiative_order: [ initiative_first, knight, party_last, spell_target, party_first ])
    enemies.each do |enemy| # with Dice.hit? stubbed below, every attack hits and kills
      participant_of(encounter, enemy).define_singleton_method(:take_damage) { |**| @current_hit_points = 0 }
    end
    rng = Random.new(1)
    caster = participant_of(encounter, knight)
    option = caster.action_options.find { |action| action.spell&.slug == "fire-bolt" }

    bonus = Dice.stub(:hit?, true) do
      build_turn_executor(encounter, rng:).war_magic_turn(actor: caster, option: option.with(target: participant_of(encounter, spell_target), gambit:),
                                                          round: 1, turn: 1)
    end

    # The attack goes to the first living enemy in initiative order, not the first or last in party order.
    assert_equal [ initiative_first.combatant.id ], bonus.results.map { |attack| attack[:target_id] }
    assert_equal Marshal.dump(Random.new(1)), Marshal.dump(rng),
      "War Magic's fallback must not consume the RNG"
  end

  test "War Magic's bonus is one weapon attack despite Extra Attack, with the marks of any attack; the Attack action keeps Extra Attack" do
    knight = seed_character("Cavaleiro Arcano", level: 10) # Extra Attack (2 attacks) and Eldritch Strike
    spell_target, other = seed_character("Campeão"), seed_character("Mestre de Batalha")
    gambit = add_rule(knight, position: 1, spell: "fire-bolt")
    encounter = prepared_encounter(party_one: [ knight ], party_two: [ spell_target, other ])
    executor = build_turn_executor(encounter)
    knight, spell_target, other = [ knight, spell_target, other ].map { |character| participant_of(encounter, character) }
    option = knight.action_options.find { |action| action.spell&.slug == "fire-bolt" }
    spell_target.add_status(Combat::Status.new(kind: "next_attack_advantage", source: other, ends: "source_turn_start")) # a Distracting Strike mark from someone else

    bonus = Dice.stub(:hit?, true) do
      executor.war_magic_turn(actor: knight, option: option.with(target: spell_target, gambit:), round: 1, turn: 1)
    end

    assert_equal 2, knight.attacks_per_action
    assert_equal [ [ spell_target.id, true ] ], bonus.results.map { |entry| entry.values_at(:target_id, :advantage) }, "one attack, with the mark's advantage"
    assert_equal [ [ "disadvantage_on_next_save", knight ] ], spell_target.statuses.map { |status| [ status.kind, status.source ] },
      "the bonus spends the mark and leaves the Eldritch Strike mark"

    # The Attack action by an attack rule on the first enemy in initiative order: the spell's target.
    attack_rule = Gambit.new(position: 2, target: :enemy, condition: :any, action_kind: :attack)
    attack = Dice.stub(:hit?, true) { executor.run(actor: knight, option: Combat::ActionOption.new(type: :attack, gambit: attack_rule), round: 1, turn: 1) }
    assert_equal [ spell_target.id ] * 2, attack.results.map { |entry| entry[:target_id] }, "the Attack action still makes attacks_per_action attacks"
  end

  test "a gambit-driven combat with Action Surge and War Magic never draws from the RNG" do
    seed = 4
    knight = seed_character("Cavaleiro Arcano", level: 7) # War Magic, one Action Surge
    add_rule(knight, position: 1, target: :self, feature: "action-surge")
    add_rule(knight, position: 2, spell: "fire-bolt")
    champion = seed_character("Campeão") # Action Surge but no rule for it: must never surge
    battle_master = seed_character("Mestre de Batalha") # two enemies, so a random pick would draw from @rng
    [ champion, battle_master ].each { |enemy| add_rule(enemy, position: 1) }
    simulation = simulator(party_one: [ knight ], party_two: [ champion, battle_master ], seed:, max_rounds: 3)

    rounds = simulation.call[:round_log]
    turns = rounds.flat_map { |round| round[:turns] }

    # War Magic follows the surge's first action only, never the extra one.
    assert_equal [ [ :action_surge, false, false ], [ :cast_spell, false, false ], [ :attack, true, false ], [ :cast_spell, false, true ] ],
                 rounds.first[:turns].select { |turn| turn[:actor_id] == knight.combatant.id }.map { |turn| [ turn.dig(:action, :type), !!turn[:bonus], !!turn[:extra] ] }
    assert turns.any? { |turn| turn[:actor_id] == champion.combatant.id }
    assert_equal Marshal.dump(Random.new(seed)), Marshal.dump(simulation.rng),
      "a gambit-driven turn, Action Surge or War Magic bonus must not consume the RNG"
  end

  private

    # A seed character starting with enough HP (by default) that nobody falls over the few rounds a test runs.
    def seed_character(name, level: nil, hit_points: 1000)
      character = PlayerCharacter.find_by!(name:)
      character.update!(level:) if level
      @hit_points[character.combatant.id] = hit_points
      character
    end

    # The simulator, with the HP the test set (#seed_character).
    def simulator(**)
      Combat::Simulator.new(hit_points: @hit_points, **)
    end

    def seed_feature(slug)
      PlayerClass.find_by!(name: "Guerreiro").class_features.find_by!(slug:)
    end

    def learn_maneuver(character, slug)
      maneuver = seed_feature(slug)
      return if character.known_maneuvers.include?(maneuver)

      character.player_character_maneuvers.find_by!(maneuver: seed_feature("battle-master-maneuver-parry")).destroy!
      character.player_character_maneuvers.create!(maneuver:)
    end

    def add_rule(character, position:, target: :enemy, condition: :any, feature: nil, spell: nil, **attributes)
      action = if feature then { action_kind: :class_feature, class_feature: seed_feature(feature) }
      elsif spell then { action_kind: :spell, spell: Spell.find_by!(slug: spell) }
      else { action_kind: :attack }
      end
      character.gambits.build(position:, target:, condition:, **action, **attributes).tap { |gambit| assert gambit.valid?, gambit.errors.full_messages.to_sentence }
    end

    # The fight with the HP the test set (#seed_character), in the given initiative order (of characters).
    def prepared_encounter(party_one:, party_two:, initiative_order: nil)
      build_encounter(party_one:, party_two:, hit_points: @hit_points, initiative_order:)
    end

    # The actor's turn against a sturdy seed enemy; returns the encounter and the actor's entries.
    def one_turn(actor)
      encounter = prepared_encounter(party_one: [ actor ], party_two: [ seed_character("Mestre de Batalha") ])
      [ encounter, build_turn_executor(encounter).take_turn(participant_of(encounter, actor), round: 1, turn: 1) ]
    end

    def uses_left(source, actor, slug)
      participant_of(source, actor).uses_left(seed_feature(slug).id)
    end

    def actor_turns(actor, result, extras: false)
      result[:round_log].flat_map { |round| round[:turns] }
        .select { |turn| turn[:actor_id] == actor.combatant.id && turn.dig(:action, :type) != :turn_passive && (extras || !turn[:extra]) }
    end
end
