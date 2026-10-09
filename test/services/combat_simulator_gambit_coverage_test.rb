require "test_helper"

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
        rule: { feature: "battle-master-maneuver-#{slug}" }, action: { type: :attack, maneuver_name: "Maneuver: #{name}" } }
    end,
    *%w[fire-bolt ray-of-frost chromatic-orb].map do |slug|
      { item: slug, actor: "Cavaleiro Arcano", rule: { spell: slug }, action: { type: :cast_spell, spell_slug: slug } }
    end,
    *%w[scorching-ray fireball].map do |slug|
      { item: slug, actor: "Cavaleiro Arcano", level: 13, spell: slug, rule: { spell: slug }, action: { type: :cast_spell, spell_slug: slug } }
    end
  ].freeze

  setup { SeedData.load_all }

  INVENTORY.each do |entry|
    item, actor, action = entry.values_at(:item, :actor, :action)

    test "inventory: a single gambit fires #{item}" do
      character = seed_character(actor, level: entry[:level])
      learn_maneuver(character, entry[:maneuver]) if entry[:maneuver]
      character.player_character_spells.find_or_create_by!(spell: Spell.find_by!(slug: entry[:spell])) if entry[:spell]
      add_rule(character, position: 1, **entry[:rule])
      enemy = seed_character(actor == "Campeão" ? "Mestre de Batalha" : "Campeão")

      turn = actor_turns(character, CombatSimulatorService.new(party_one: [ character ], party_two: [ enemy ], seed: 1, max_rounds: 1).call).first

      assert_equal action, turn[:action].slice(:type, :maneuver_name, :feature_slug, :spell_slug), "#{item}: wrong action"
      assert_equal 1, turn.dig(:gambit, :position), "#{item}: not fired by the rule"
      assert_equal [ enemy.id ], turn[:results].map { |result| result[:target_id] }.uniq if action[:type] == :attack
    end
  end

  test "hp_above fires only strictly above the threshold" do
    actor = seed_character("Campeão")
    enemy = seed_character("Mestre de Batalha")
    gambit = add_rule(actor, position: 1, condition: :hp_above, condition_value: 50)
    service = prepared_service(party_one: [ actor ], party_two: [ enemy ])
    enemy.max_hit_points = 20

    enemy.current_hit_points = 10 # exactly 50%
    assert_nil service.send(:gambit_target, actor:, gambit:)

    enemy.current_hit_points = 11
    assert_equal enemy, service.send(:gambit_target, actor:, gambit:)

    # 63/125 = 50.4%: above 50% even though it rounds to 50.
    enemy.max_hit_points = 125
    enemy.current_hit_points = 63
    assert_equal enemy, service.send(:gambit_target, actor:, gambit:)
  end

  test "highest_hp picks the healthiest enemy, ties going to initiative order" do
    actor = seed_character("Cavaleiro Arcano")
    first_in_party, second_in_party = seed_character("Campeão"), seed_character("Mestre de Batalha")
    gambit = add_rule(actor, position: 1, condition: :highest_hp)
    service = prepared_service(party_one: [ actor ], party_two: [ first_in_party, second_in_party ],
                               initiative_order: [ second_in_party, actor, first_in_party ])
    first_in_party.current_hit_points = second_in_party.current_hit_points = 30

    assert_equal second_in_party, service.send(:gambit_target, actor:, gambit:), "a tie goes to the first in initiative order"

    first_in_party.current_hit_points = 31
    assert_equal first_in_party, service.send(:gambit_target, actor:, gambit:)
  end

  test "marked and unmarked look at marks the actor would use: someone else's, never its own" do
    actor = seed_character("Mestre de Batalha")
    ally = seed_character("Cavaleiro Arcano")
    first, second = seed_character("Campeão"), player_characters(:aragorn) # the seeds hold only three characters
    marked = add_rule(actor, position: 1, condition: :marked)
    unmarked = add_rule(actor, position: 2, condition: :unmarked)
    service = prepared_service(party_one: [ actor, ally ], party_two: [ first, second ], initiative_order: [ actor, ally, first, second ])
    marks = service.instance_variable_get(:@advantage_marks)

    marks[first.id] << actor.id # the actor's own mark: its next attack would not get advantage from it
    assert_nil service.send(:gambit_target, actor:, gambit: marked)
    assert_equal first, service.send(:gambit_target, actor:, gambit: unmarked)

    marks[second.id] << ally.id
    assert_equal second, service.send(:gambit_target, actor:, gambit: marked)
    assert_equal first, service.send(:gambit_target, actor:, gambit: unmarked)

    marks[first.id] << ally.id
    assert_equal first, service.send(:gambit_target, actor:, gambit: marked)
    assert_nil service.send(:gambit_target, actor:, gambit: unmarked)
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
        gambits = [ add_rule(actor, position: 1, condition: :resource_at_least, condition_value: value, **rule) ]
        service = prepared_service(party_one: [ actor ], party_two: [ enemy ])
        service.send(:choose_gambit_action, actor:, gambits:, available: service.send(:available_actions_for, actor:))
      end

      assert at_least.(remaining), "#{resource}: #{remaining} left must satisfy ≥ #{remaining}"
      assert_equal 1, at_least.(remaining)[:gambit].position
      assert_nil at_least.(remaining + 1), "#{resource}: #{remaining} left must not satisfy ≥ #{remaining + 1}"
    end
  end

  test "resource_at_least on a spell counts only the slots of the spell's own level" do
    # Level 13: slots 4/3/2, so only the spell's level (3: two slots) separates the thresholds below.
    knight = seed_character("Cavaleiro Arcano", level: 13)
    knight.player_character_spells.create!(spell: Spell.find_by!(slug: "fireball"))
    knight.player_character_spells.create!(spell: Spell.find_by!(slug: "scorching-ray"))
    assert_equal({ 1 => 4, 2 => 3, 3 => 2, 4 => 0 }, knight.available_spell_slots)
    service = prepared_service(party_one: [ knight ], party_two: [ player_characters(:aragorn) ])
    fires = lambda do |spell, value|
      knight.gambits.reset
      gambits = [ add_rule(knight, position: 1, condition: :resource_at_least, condition_value: value, spell:) ]
      service.send(:choose_gambit_action, actor: knight, gambits:, available: service.send(:available_actions_for, actor: knight)).present?
    end

    assert fires.("fireball", 2)
    assert_not fires.("fireball", 3), "3 slots of another level must not count for a level 3 spell"

    knight.available_spell_slots[2] = 1 # spending level 2 slots changes only the level 2 rule
    assert fires.("fireball", 2)
    assert_not fires.("scorching-ray", 2)
    assert fires.("scorching-ray", 1)
  end

  test "resource_at_least counts unlimited uses as available and picks the first candidate in initiative order" do
    actor = seed_character("Campeão")
    first, second = seed_character("Mestre de Batalha"), seed_character("Cavaleiro Arcano")
    service = prepared_service(party_one: [ actor ], party_two: [ first, second ], initiative_order: [ second, actor, first ])
    gambit = add_rule(actor, position: 1, target: :enemy, condition: :resource_at_least, condition_value: 20,
                             feature: "battle-master-maneuver-precision-attack")

    assert service.send(:gambit_resource_at_least?, actor:, action: { type: :class_feature, uses_remaining: nil }, minimum: 20)
    assert_equal second, service.send(:gambit_target, actor:, gambit:)
  end

  test "resource_at_least on an Action Surge rule counts its uses" do
    champion = seed_character("Campeão") # level 5: one Action Surge
    service = prepared_service(party_one: [ champion ], party_two: [ seed_character("Mestre de Batalha") ])
    fires = lambda do |value|
      champion.gambits.reset
      gambits = [ add_rule(champion, position: 1, target: :self, condition: :resource_at_least, condition_value: value, feature: "action-surge") ]
      service.send(:choose_gambit_action, actor: champion, gambits:, available: service.send(:available_actions_for, actor: champion))&.dig(:type)
    end

    assert_equal 1, uses_left(service, champion, "action-surge")
    assert_equal :action_surge, fires.(1)
    assert_nil fires.(2)
  end

  test "Action Surge through a gambit: one use, a marker, then the normal action and the extra one" do
    actor = seed_character("Campeão")
    add_rule(actor, position: 1, target: :self, feature: "action-surge")
    add_rule(actor, position: 2)
    service, turns = one_turn(actor)

    assert_equal [ [ :action_surge, 1, false ], [ :attack, 2, false ], [ :attack, 2, true ] ],
                 turns.map { |turn| [ turn.dig(:action, :type), turn.dig(:gambit, :position), !!turn[:extra] ] }
    assert_equal [], turns.first[:results]
    assert_equal 0, uses_left(service, actor, "action-surge")
  end

  test "Action Surge through a gambit spends exactly one use and never chains, even with two uses" do
    actor = seed_character("Campeão", level: 17)
    add_rule(actor, position: 1, target: :self, feature: "action-surge")
    add_rule(actor, position: 2)
    service, turns = one_turn(actor, uses: { "action-surge" => 2 })

    assert_equal [ :action_surge, :attack, :attack ], turns.map { |turn| turn.dig(:action, :type) }
    assert_equal 1, uses_left(service, actor, "action-surge")
  end

  test "nothing happens after the fight ends inside an Action Surge: no extra action, no War Magic bonus" do
    # Level 18: Improved War Magic (a bonus attack after any spell) and level 3 slots. Fireball always
    # deals damage (half on a save), so it kills the 1 HP enemy: the surge's first action ends the fight.
    knight = seed_character("Cavaleiro Arcano", level: 18)
    knight.player_character_spells.create!(spell: Spell.find_by!(slug: "fireball"))
    add_rule(knight, position: 1, target: :self, feature: "action-surge")
    add_rule(knight, position: 2, spell: "fireball")
    add_rule(knight, position: 3, target: :self, feature: "second-wind")
    enemy = seed_character("Campeão")
    service = prepared_service(party_one: [ knight ], party_two: [ enemy ])
    enemy.current_hit_points = 1

    turns = service.send(:execute_round, round_number: 1, initiative_order: service.instance_variable_get(:@initiative_order))

    assert enemy.dead?
    assert_equal [ [ :action_surge, 1 ], [ :cast_spell, 2 ] ], turns.map { |turn| [ turn.dig(:action, :type), turn.dig(:gambit, :position) ] }
    assert_equal 1, uses_left(service, knight, "second-wind")
  end

  test "inside an Action Surge each evaluation may stand idle, and only the extra one is marked extra" do
    actor = seed_character("Campeão")
    add_rule(actor, position: 1, target: :self, feature: "action-surge")
    _, turns = one_turn(actor)

    assert_equal [ [ :action_surge, false ], [ :idle, false ], [ :idle, true ] ], turns.map { |turn| [ turn.dig(:action, :type), !!turn[:extra] ] }
  end

  test "a gambit-driven actor with no Action Surge rule never surges, whether it acts or stands idle" do
    { "acting" => {}, "idle" => { condition: :hp_below, condition_value: 1 } }.each do |scenario, rule|
      actor = seed_character("Campeão")
      actor.gambits.reset
      add_rule(actor, position: 1, **rule)
      service = CombatSimulatorService.new(party_one: [ actor ], party_two: [ seed_character("Mestre de Batalha") ], seed: 1, max_rounds: 3)

      turns = actor_turns(actor, service.call, extras: true)

      assert_equal 3, turns.size, scenario
      assert turns.none? { |turn| turn[:extra] || turn.dig(:action, :type) == :action_surge }, "#{scenario}: surged without a rule"
      assert_equal 1, uses_left(service, actor, "action-surge"), scenario
    end
  end

  test "War Magic for a gambit-driven actor hits the spell's target, else the first living enemy in initiative order" do
    actor = seed_character("Cavaleiro Arcano", level: 7)
    first, second = seed_character("Campeão"), seed_character("Mestre de Batalha")
    gambit = add_rule(actor, position: 1, spell: "fire-bolt")
    service = prepared_service(party_one: [ actor ], party_two: [ first, second ], initiative_order: [ first, actor, second ])
    chosen_action = service.send(:available_actions_for, actor:).find { |action| action[:spell]&.slug == "fire-bolt" }
    bonus_targets = lambda do
      service.send(:war_magic_turn, actor:, chosen_action: chosen_action.merge(target: second, gambit:), round_number: 1, turn_index: 1)[:results]
        .map { |attack| attack[:target_id] }
    end

    assert_equal [ second.id ] * 2, bonus_targets.call, "Extra Attack at level 7: both on the spell's target"

    second.current_hit_points = 0
    assert_equal [ first.id ] * 2, bonus_targets.call
    assert_equal Marshal.dump(Random.new(1)), Marshal.dump(service.instance_variable_get(:@rng))
  end

  test "War Magic's fallback with several enemies left: the first living one in initiative order, also once the focus falls" do
    knight = seed_character("Cavaleiro Arcano", level: 7) # Extra Attack: the bonus action makes 2 attacks
    spell_target, party_first, initiative_first, party_last =
      seed_character("Campeão"), seed_character("Mestre de Batalha"), player_characters(:aragorn), player_characters(:aragorn_copy)
    enemies = [ spell_target, party_first, initiative_first, party_last ]
    enemies.each do |enemy|
      enemy.current_hit_points = 1000
      enemy.define_singleton_method(:get_attacked) do |attack_roll:| # every attack hits and kills
        self.current_hit_points = 0
        { success: true, attack_roll:, message: "Hit!" }
      end
    end
    gambit = add_rule(knight, position: 1, spell: "fire-bolt")
    service = prepared_service(party_one: [ knight ], party_two: enemies,
                               initiative_order: [ initiative_first, knight, party_last, spell_target, party_first ])
    chosen_action = service.send(:available_actions_for, actor: knight).find { |action| action[:spell]&.slug == "fire-bolt" }
    spell_target.current_hit_points = 0 # the spell killed its own target, leaving three enemies alive

    bonus = service.send(:war_magic_turn, actor: knight, chosen_action: chosen_action.merge(target: spell_target, gambit:), round_number: 1, turn_index: 1)

    # The first attack goes to the first living enemy in initiative order (not the first or last in party
    # order) and kills it; the second re-runs the fallback on the two still alive.
    assert_equal [ initiative_first.id, party_last.id ], bonus[:results].map { |attack| attack[:target_id] }
    assert_not party_first.dead?
    assert_equal Marshal.dump(Random.new(1)), Marshal.dump(service.instance_variable_get(:@rng)),
      "War Magic's fallback must not consume @rng"
  end

  test "War Magic's focus falls on the first attack: the second picks the first living enemy in initiative order among three" do
    knight = seed_character("Cavaleiro Arcano", level: 7)
    spell_target, party_first, initiative_first, party_last =
      seed_character("Campeão"), seed_character("Mestre de Batalha"), player_characters(:aragorn), player_characters(:aragorn_copy)
    enemies = [ spell_target, party_first, initiative_first, party_last ]
    enemies.each do |enemy|
      enemy.current_hit_points = 1000
      enemy.define_singleton_method(:get_attacked) do |attack_roll:| # every attack hits and kills
        self.current_hit_points = 0
        { success: true, attack_roll:, message: "Hit!" }
      end
    end
    gambit = add_rule(knight, position: 1, spell: "fire-bolt")
    service = prepared_service(party_one: [ knight ], party_two: enemies,
                               initiative_order: [ initiative_first, knight, party_last, spell_target, party_first ])
    chosen_action = service.send(:available_actions_for, actor: knight).find { |action| action[:spell]&.slug == "fire-bolt" }

    bonus = service.send(:war_magic_turn, actor: knight, chosen_action: chosen_action.merge(target: spell_target, gambit:), round_number: 1, turn_index: 1)

    # initiative_first sits in the middle of party order, so neither .first nor .last can pass.
    assert_equal [ spell_target.id, initiative_first.id ], bonus[:results].map { |attack| attack[:target_id] }
    assert_equal Marshal.dump(Random.new(1)), Marshal.dump(service.instance_variable_get(:@rng))
  end

  test "a gambit-driven combat with Action Surge and War Magic never draws from @rng" do
    seed = 4
    knight = seed_character("Cavaleiro Arcano", level: 7) # War Magic, one Action Surge
    add_rule(knight, position: 1, target: :self, feature: "action-surge")
    add_rule(knight, position: 2, spell: "fire-bolt")
    champion = seed_character("Campeão") # Action Surge but no rule for it: must never surge
    battle_master = seed_character("Mestre de Batalha") # two enemies, so a random pick would draw from @rng
    [ champion, battle_master ].each { |enemy| add_rule(enemy, position: 1) }
    service = CombatSimulatorService.new(party_one: [ knight ], party_two: [ champion, battle_master ], seed:, max_rounds: 3)

    rounds = service.call[:round_log]
    turns = rounds.flat_map { |round| round[:turns] }

    # War Magic follows the surge's first action only, never the extra one.
    assert_equal [ [ :action_surge, false, false ], [ :cast_spell, false, false ], [ :attack, true, false ], [ :cast_spell, false, true ] ],
                 rounds.first[:turns].select { |turn| turn[:actor_id] == knight.id }.map { |turn| [ turn.dig(:action, :type), !!turn[:bonus], !!turn[:extra] ] }
    assert turns.any? { |turn| turn[:actor_id] == champion.id }
    assert_equal Marshal.dump(Random.new(seed)), Marshal.dump(service.instance_variable_get(:@rng)),
      "a gambit-driven turn, Action Surge or War Magic bonus must not consume @rng"
  end

  private

    # A seed character with enough HP that nobody falls over the few rounds a test runs.
    def seed_character(name, level: nil)
      character = PlayerCharacter.find_by!(name:)
      character.update!(level:) if level
      character.current_hit_points = 1000
      character
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

    def prepared_service(party_one:, party_two:, initiative_order: party_one + party_two)
      service = CombatSimulatorService.new(party_one:, party_two:, seed: 1, max_rounds: 1)
      service.send(:initialize_state)
      service.instance_variable_set(:@initiative_order, initiative_order)
      service
    end

    # Runs one round with the actor first, against a sturdy seed enemy; returns the actor's entries.
    def one_turn(actor, uses: {})
      service = prepared_service(party_one: [ actor ], party_two: [ seed_character("Mestre de Batalha") ])
      uses.each { |slug, count| service.instance_variable_get(:@uses_remaining)[actor.id][seed_feature(slug).id] = count }
      turns = service.send(:execute_round, round_number: 1, initiative_order: service.instance_variable_get(:@initiative_order))
      [ service, turns.select { |turn| turn[:actor_id] == actor.id } ]
    end

    def uses_left(service, actor, slug)
      service.instance_variable_get(:@uses_remaining)[actor.id][seed_feature(slug).id]
    end

    def actor_turns(actor, result, extras: false)
      result[:round_log].flat_map { |round| round[:turns] }
        .select { |turn| turn[:actor_id] == actor.id && turn.dig(:action, :type) != :turn_passive && (extras || !turn[:extra]) }
    end
end
