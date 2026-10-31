require "test_helper"

class Combat::SimulatorTest < ActiveSupport::TestCase
  SEED_WITH_REVERSED_INITIATIVE = 3

  setup { @hit_points = {} }

  test "returns the expected contract shape" do
    party_one = [ fresh_character(:aragorn) ]
    party_two = [ fresh_character(:aragorn_copy) ]

    result = simulator(party_one:, party_two:, seed: 1234, max_rounds: 3).call

    assert_includes result.keys, :winning_party
    assert_includes result.keys, :total_rounds
    assert_includes result.keys, :round_log
    assert_includes result.keys, :draw
    assert_includes result.keys, :outcome
    assert result[:round_log].is_a?(Array)
    assert result[:total_rounds] <= 3
  end

  test "is deterministic when using the same seed" do
    result_one = simulator(
      party_one: [ fresh_character(:thorin) ],
      party_two: [ fresh_character(:aragorn), fresh_character(:aragorn_copy) ],
      seed: 77,
      max_rounds: 5
    ).call

    result_two = simulator(
      party_one: [ fresh_character(:thorin) ],
      party_two: [ fresh_character(:aragorn), fresh_character(:aragorn_copy) ],
      seed: 77,
      max_rounds: 5
    ).call

    assert_equal result_one, result_two
  end

  test "without gambits, a fixed seed replays the exact same random choices" do
    # Recorded from the code before gambits existed: the random path must not change.
    party_one = %i[thorin fighter_archer].map { |name| fresh_character(name) }
    party_two = %i[aragorn aragorn_copy fighter_defender].map { |name| fresh_character(name) }
    name_of = %i[thorin fighter_archer aragorn aragorn_copy fighter_defender].index_by { |name| player_characters(name).combatant.id }

    result = simulator(party_one:, party_two:, seed: 77, max_rounds: 3).call

    choices = result[:round_log].flat_map { |round| round[:turns] }.flat_map do |turn|
      targets = turn[:results].filter_map { |entry| name_of[entry[:target_id]] }
      (targets.presence || [ nil ]).map { |target| [ name_of[turn[:actor_id]], turn.dig(:action, :type), target ] }
    end
    assert_equal [
      [ :fighter_defender, :class_feature, nil ], [ :thorin, :class_feature, nil ], [ :thorin, :attack, :aragorn ],
      [ :aragorn_copy, :attack, :fighter_archer ], [ :fighter_archer, :class_feature, nil ], [ :aragorn, :attack, :fighter_archer ],
      [ :fighter_defender, :attack, :thorin ], [ :thorin, :attack, :aragorn_copy ], [ :aragorn_copy, :class_feature, nil ],
      [ :fighter_archer, :attack, :aragorn_copy ], [ :aragorn, :attack, :fighter_archer ], [ :fighter_defender, :attack, :thorin ],
      [ :thorin, :attack, :fighter_defender ], [ :aragorn_copy, :attack, :thorin ], [ :fighter_archer, :attack, :fighter_defender ],
      [ :aragorn, :attack, :fighter_archer ]
    ], choices
  end

  test "without gambits, a caster with War Magic replays the exact same random choices" do
    # Recorded from the code before gambits existed: the coin flip between spells and attacks, and the
    # War Magic bonus attack after a cantrip, must not change on the random path.
    eldritch_knight = sturdy(spellcaster_with_known_spells(:eldritch_knight_seven))
    enemies = %i[aragorn aragorn_copy].map { |name| sturdy(fresh_character(name)) }
    name_of = { eldritch_knight.combatant.id => :eldritch_knight_seven, enemies.first.combatant.id => :aragorn, enemies.second.combatant.id => :aragorn_copy }

    result = simulator(party_one: [ eldritch_knight ], party_two: enemies, seed: 6, max_rounds: 3).call

    choices = result[:round_log].flat_map { |round| round[:turns] }.flat_map do |turn|
      targets = turn[:results].filter_map { |entry| name_of[entry[:target_id]] }
      (targets.presence || [ nil ]).map { |target| [ name_of[turn[:actor_id]], turn.dig(:action, :type), target, !!turn[:bonus] ] }
    end
    assert_equal [
      [ :eldritch_knight_seven, :cast_spell, nil, false ], [ :eldritch_knight_seven, :attack, :aragorn_copy, true ],
      [ :eldritch_knight_seven, :cast_spell, nil, false ], [ :aragorn, :attack, :eldritch_knight_seven, false ],
      [ :aragorn_copy, :class_feature, nil, false ], [ :eldritch_knight_seven, :class_feature, nil, false ],
      [ :aragorn, :class_feature, nil, false ], [ :aragorn_copy, :attack, :eldritch_knight_seven, false ],
      [ :eldritch_knight_seven, :cast_spell, nil, false ], [ :aragorn, :attack, :eldritch_knight_seven, false ],
      [ :aragorn_copy, :attack, :eldritch_knight_seven, false ]
    ], choices
  end

  test "participants are built in party order, so uses rolled with dice replay the same for a seed" do
    rolled = class_features(:fighter_second_wind).dup.tap { |feature| feature.update!(name: "Test Dice Uses", slug: "test-dice-uses") }
    rolled.class_feature_unlocks.create!(level: 1, description: "Test: uses rolled with a die.", uses_formula: "1d20")
    first, second = fresh_character(:thorin), fresh_character(:aragorn)
    simulation = simulator(party_one: [ first ], party_two: [ second ], seed: 9, max_rounds: 1)
    simulation.call

    Random.srand(9)
    expected = Array.new(2) { Dice.roll(dice: "1d20").total }
    assert_not_equal expected.first, expected.last, "the seed must tell the two rolls apart"
    assert_equal expected, [ first, second ].map { |sheet| participant_of(simulation, sheet).uses_left(rolled.id) }
  end

  test "a simulation only reads the sheets: a batch's come out unchanged and cannot be saved" do
    merlin, aragorn = player_characters(:merlin), player_characters(:aragorn)
    batch = SimulationBatch.create!(party_one_ids: [ merlin.combatant.id ], party_two_ids: [ aragorn.combatant.id ], seed: 1)
    sheets = [ batch.party_one.sole, batch.party_two.sole ]
    reading = -> { sheets.map { |sheet| [ sheet.attributes, sheet.combatant.attributes, sheet.spell_slots ] } }
    before = reading.call
    simulation = Combat::Simulator.new(party_one: [ sheets.first ], party_two: [ sheets.second ], seed: 3, hit_points: batch.hit_points)

    rounds = simulation.call[:round_log]

    assert rounds.flat_map { |round| round[:turns] }.any? { |turn| turn.dig(:action, :spell_slug) == "magic-missile" }, "the seed must spend a slot"
    assert_operator participant_of(simulation, sheets.first).available_spell_slots[1], :<, merlin.spell_slots[1]
    assert rounds.flat_map { |round| round[:turns] }.flat_map { |turn| turn[:results] }.any? { |result| result[:hp_after] < result[:hp_before] }
    assert_equal before, reading.call
    sheets.each do |sheet|
      assert_not sheet.changed?
      assert_not sheet.combatant.changed?
      %i[current_hit_points current_hit_points= available_spell_slots take_damage cast_spell].each { |state| assert_not_respond_to sheet, state }
      assert_raises(ActiveRecord::ReadOnlyRecord) { sheet.save! }
      assert_raises(ActiveRecord::ReadOnlyRecord) { sheet.combatant.save! }
    end
  end

  test "signals explicit draw on simultaneous elimination" do
    fallen_one = fresh_character(:aragorn)
    fallen_two = fresh_character(:aragorn_copy)
    @hit_points[fallen_one.combatant.id] = @hit_points[fallen_two.combatant.id] = 0

    result = simulator(
      party_one: [ fallen_one ],
      party_two: [ fallen_two ],
      seed: 1,
      max_rounds: 5
    ).call

    assert_equal true, result[:draw]
    assert_nil result[:winning_party]
    assert_equal :draw, result[:outcome]
    assert_equal 0, result[:total_rounds]
  end

  test "abort_if aborts the simulation in progress between rounds" do
    rounds_started = 0
    simulation = simulator(
      party_one: [ fresh_character(:thorin) ],
      party_two: [ fresh_character(:aragorn) ],
      seed: 42,
      max_rounds: 5,
      abort_if: -> { (rounds_started += 1) > 1 }
    )

    assert_raises(Combat::Simulator::Aborted) { simulation.call }
    assert_equal 2, rounds_started
  end

  test "weapon attack entries carry the target's HP before and after the hit" do
    target = fresh_character(:aragorn_copy)
    result = simulator(party_one: [ fresh_character(:thorin) ], party_two: [ target ], seed: 42, max_rounds: 3).call

    attacks = result[:round_log].flat_map { |round| round[:turns] }.flat_map { |turn| turn[:results] }.select { |entry| entry[:kind] == :attack }
    assert attacks.any?
    attacks.each do |attack|
      assert_operator attack[:hp_after], :<=, attack[:hp_before]
      assert_equal attack[:hp_before], attack[:hp_after] unless attack.dig(:attack_roll, :hit)
    end
  end

  test "loads each combatant's unlocked features once per simulation, not on every turn" do
    party_one = [ fresh_character(:battle_master_seven) ]
    party_two = [ fresh_character(:eldritch_knight_seven), fresh_character(:champion_seven) ]

    unlock_lookups = 0
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      unlock_lookups += 1 if payload[:sql].include?('FROM "class_features" LEFT OUTER JOIN "class_feature_unlocks"')
    end
    result = simulator(party_one:, party_two:, seed: 3, max_rounds: 10).call
    ActiveSupport::Notifications.unsubscribe(subscription)

    assert_equal 10, result[:total_rounds], "the fight must be long enough for a per-turn lookup to show"
    # One lookup per combatant (PlayerCharacter#feature_unlocks, shared by the simulator and the passives),
    # however long the fight.
    assert_equal 3, unlock_lookups
  end

  test "respects max_rounds stop condition" do
    result = simulator(
      party_one: [ fresh_character(:thorin) ],
      party_two: [ fresh_character(:aragorn) ],
      seed: 42,
      max_rounds: 1
    ).call

    assert_equal 1, result[:total_rounds]
  end

  test "Survivor heals a Champion at half HP or below at the start of their turn" do
    champion = fresh_character(:champion_eighteen)
    starting_hit_points = @hit_points[champion.combatant.id] = champion.max_hit_points / 2

    simulation = simulator(party_one: [ champion ], party_two: [ fresh_character(:aragorn) ], seed: 99, max_rounds: 1)
    result = simulation.call

    passive_entries = result[:round_log].flat_map { |round| round[:turns] }
      .select { |turn| turn[:actor_id] == champion.combatant.id && turn.dig(:action, :type) == :turn_passive && turn.dig(:action, :trigger) == "turn_start" }

    assert_equal 1, passive_entries.size
    assert_equal :heal, passive_entries.first[:results].first[:kind]
    assert_operator participant_of(simulation, champion).current_hit_points, :>, starting_hit_points
  end

  test "a Distracting Strike mark expires at the start of its owner's next turn, leaving other owners' marks alone" do
    battle_master = battle_master_with_known_maneuvers(:battle_master_seven)
    ally = fresh_character(:aragorn_copy)
    target = hittable_target(armor_class: 1)
    add_gambit(battle_master, position: 1, condition: :hp_below, condition_value: 1) # it stands idle, so no attack spends a mark
    simulation = simulator(party_one: [ battle_master, ally ], party_two: [ target ], seed: 1, max_rounds: 1)

    simulation.call { |encounter| mark_and_play_first(encounter, target:, sources: [ ally, battle_master ], first: battle_master) }

    assert_equal [ ally.combatant.id ], participant_of(simulation, target).statuses.map { |status| status.source.id }
  end

  test "a fallen Battle Master's mark still expires when its turn comes up" do
    battle_master = battle_master_with_known_maneuvers(:battle_master_seven)
    ally = fresh_character(:aragorn_copy)
    target = hittable_target(armor_class: 1)
    @hit_points[battle_master.combatant.id] = 0
    simulation = simulator(party_one: [ battle_master, ally ], party_two: [ target ], seed: 1, max_rounds: 1)

    simulation.call { |encounter| mark_and_play_first(encounter, target:, sources: [ ally, battle_master ], first: battle_master) }

    assert_equal [ ally.combatant.id ], participant_of(simulation, target).statuses.map { |status| status.source.id }
  end

  test "an Eldritch Knight autonomously casts a spell during a simulated round" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven)
    target = fresh_character(:aragorn)

    result = simulator(party_one: [ caster ], party_two: [ target ], seed: 2, max_rounds: 1).call

    cast_turn = result[:round_log].flat_map { |round| round[:turns] }
      .find { |turn| turn[:actor_id] == caster.combatant.id && turn.dig(:action, :type) == :cast_spell }

    assert cast_turn, "expected the Eldritch Knight to autonomously cast a spell"
    assert_equal "magic-missile", cast_turn.dig(:action, :spell_slug)
    assert_equal :damage, cast_turn[:results].first[:kind]
    assert_equal 12, cast_turn[:results].first[:amount]
  end

  test "gambits: with two valid rules the top one wins, and a rule out of uses is skipped" do
    second_wind = class_features(:fighter_second_wind)
    actor = sturdy(fresh_character(:aragorn))
    add_gambit(actor, position: 1, target: :self, action_kind: :class_feature, class_feature: second_wind)
    add_gambit(actor, position: 2)

    turns = actor_turns(actor:, result: gambit_simulation(actor:, max_rounds: 2).call)

    assert_equal [ :class_feature, :attack ], turns.map { |turn| turn.dig(:action, :type) }
    assert_equal({ position: 1, rule: "Self: qualquer → Second Wind" }, turns.first[:gambit])
    assert_equal({ position: 2, rule: "Inimigo: qualquer → Ataque" }, turns.second[:gambit])
  end

  test "gambits: a rule whose condition finds no target is skipped and the next one fires" do
    actor = sturdy(fresh_character(:aragorn))
    add_gambit(actor, position: 1, condition: :hp_below, condition_value: 10)
    add_gambit(actor, position: 2, target: :self, action_kind: :class_feature, class_feature: class_features(:fighter_second_wind))

    turn = actor_turns(actor:, result: gambit_simulation(actor:).call).first

    assert_equal "second-wind", turn.dig(:action, :feature_slug)
    assert_equal 2, turn.dig(:gambit, :position)
  end

  test "gambits: a rule with a maneuver the character does not know is skipped" do
    precision = class_features(:fighter_battle_master_maneuver_precision_attack)
    actor = battle_master_with_known_maneuvers(:battle_master_seven)
    actor.player_character_maneuvers.where(maneuver: precision).destroy_all
    add_gambit(actor, position: 1, action_kind: :class_feature, class_feature: precision)
    add_gambit(actor, position: 2, action_kind: :class_feature, class_feature: class_features(:fighter_battle_master_maneuver_distracting_strike))

    turn = actor_turns(actor:, result: gambit_simulation(actor:).call).first

    assert_equal "Maneuver: Distracting Strike", turn.dig(:action, :riders, 0, :feature_name)
    assert_equal 2, turn.dig(:gambit, :position)
  end

  test "gambits: when no rule fires the character stands idle" do
    actor = sturdy(fresh_character(:aragorn))
    enemy = sturdy(fresh_character(:merlin))
    add_gambit(actor, position: 1, condition: :hp_below, condition_value: 10)

    simulation = gambit_simulation(actor:, enemy:)
    result = simulation.call
    turns = actor_turns(actor:, result:)

    assert_equal [ { type: :idle } ], turns.map { |turn| turn[:action] }
    assert_equal [], turns.first[:results]
    assert_equal 1000, participant_of(simulation, enemy).current_hit_points
    assert_nothing_raised { SimulationRun.metrics(result[:round_log]) }
  end

  test "gambits: lowest HP picks the weakest enemy, ties going to initiative order" do
    run = lambda do |weaken: nil|
      actor = sturdy(fresh_character(:thorin))
      enemies = [ fresh_character(:aragorn), fresh_character(:aragorn_copy) ]
      enemies.find { |enemy| enemy.combatant.id == weaken }&.then { |enemy| @hit_points[enemy.combatant.id] = enemy.max_hit_points - 5 }
      add_gambit(actor, position: 1, condition: :lowest_hp)
      simulation = simulator(party_one: [ actor ], party_two: enemies, seed: SEED_WITH_REVERSED_INITIATIVE, max_rounds: 1)
      first_target = actor_turns(actor:, result: simulation.call).first[:results].first[:target_id]
      [ first_target, simulation.encounter.initiative_order.map(&:id) - [ actor.combatant.id ] ]
    end

    target, order = run.call
    assert_equal [ player_characters(:aragorn_copy).combatant.id, player_characters(:aragorn).combatant.id ], order,
      "the seed must put the enemies in initiative order opposite to their party order, or the tie-break is untested"
    assert_equal order.first, target

    target, = run.(weaken: order.last)
    assert_equal order.last, target
  end

  test "gambits: the same seed and the same gambits give the same result, with several rules firing" do
    # Rule 1 fires once any enemy is hurt; rules 2-6 always fire, so only the priority order decides
    # which one wins. A shuffled order matches the expected position of an actor's first gambit turn
    # with probability at most 1/5 (a given rule first among the 5 or 6 that fire), independently per
    # actor: two runs both matching the expected positions by chance is at most (1/5)**12 ≈ 4e-9.
    run = lambda do
      party_one = %i[aragorn fighter_archer merlin].map { |name| fresh_character(name) }
      party_two = %i[aragorn_copy fighter_defender elora].map { |name| fresh_character(name) }
      (party_one + party_two).each do |character|
        add_gambit(character, position: 1, condition: :hp_below, condition_value: 99)
        (2..6).each { |position| add_gambit(character, position:, condition: position.even? ? :any : :lowest_hp) }
      end
      simulator(party_one:, party_two:, seed: 77, max_rounds: 3).call
    end

    first = run.call
    second = run.call
    gambit_turns = first[:round_log].flat_map { |round| round[:turns] }.select { |turn| turn[:gambit] }
    positions = gambit_turns.map { |turn| turn.dig(:gambit, :position) }

    assert_operator positions.uniq.size, :>=, 2
    assert_equal 6, gambit_turns.map { |turn| turn[:actor_id] }.uniq.size
    assert_equal [ 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1 ], positions
    assert_equal first, second
  end

  test "gambits: given a copy of the rules, the simulation plays and logs the copy, not the combatant's own gambits" do
    actor = sturdy(fresh_character(:aragorn))
    add_gambit(actor, position: 1) # its own rule: an attack
    second_wind = Gambit.new(position: 1, target: :self, condition: :any, action_kind: :class_feature, class_feature: class_features(:fighter_second_wind))
    disabled = Gambit.new(position: 2, target: :enemy, condition: :any, action_kind: :attack, enabled: false)
    copy = { actor.combatant.id.to_s => [ disabled.snapshot, second_wind.snapshot.merge("label" => "rótulo da cópia") ] }

    result = simulator(party_one: [ actor ], party_two: [ sturdy(fresh_character(:merlin)) ], seed: 5, max_rounds: 1, gambits: copy).call

    turn = actor_turns(actor:, result:).first
    assert_equal [ :class_feature, { position: 1, rule: "rótulo da cópia" } ], [ turn.dig(:action, :type), turn[:gambit] ]
  end

  test "the result lists every combatant's initiative roll in the order they act" do
    combatants = %i[aragorn thorin aragorn_copy merlin].map { |name| sturdy(fresh_character(name)) }

    result = simulator(party_one: combatants.first(2), party_two: combatants.last(2), seed: 1, max_rounds: 1).call

    initiative = result[:initiative]
    assert_equal combatants.map { it.combatant.id }.sort, initiative.pluck(:actor_id).sort
    assert_equal initiative.pluck(:actor_id), result[:round_log].first[:turns].pluck(:actor_id).uniq, "round 1 plays in the logged order"
    assert_not_equal combatants.map { it.combatant.id }, initiative.pluck(:actor_id), "the seed must put them out of party order"
    assert_equal initiative.pluck(:total).sort.reverse, initiative.pluck(:total)
    initiative.each do |entry|
      assert_equal entry[:natural] + combatants.find { |combatant| combatant.combatant.id == entry[:actor_id] }.initiative, entry[:total]
      assert_includes 1..20, entry[:natural]
    end
  end

  test "without gambits, every decision entry is logged as random, Action Surge's extra and the War Magic bonus included" do
    eldritch_knight = sturdy(spellcaster_with_known_spells(:eldritch_knight_seven))
    enemies = %i[aragorn aragorn_copy].map { |name| sturdy(fresh_character(name)) }

    entries = simulator(party_one: [ eldritch_knight ], party_two: enemies, seed: 6, max_rounds: 3).call[:round_log].flat_map { |round| round[:turns] }

    assert entries.any? { |entry| entry[:bonus] }, "the scenario must include a War Magic bonus"
    assert entries.any? { |entry| entry[:extra] }, "the scenario must include an Action Surge extra action"
    assert_equal [ "aleatório" ], entries.map { |entry| entry.fetch(:gambit, :missing) }.uniq
  end

  test "gambits: a character whose gambits are all disabled plays exactly like one without gambits" do
    run = lambda do |with_disabled_gambits:|
      actor = fresh_character(:thorin)
      if with_disabled_gambits
        add_gambit(actor, position: 1, enabled: false)
        add_gambit(actor, position: 2, target: :self, action_kind: :class_feature, class_feature: class_features(:fighter_second_wind), enabled: false)
      end
      simulator(party_one: [ actor ], party_two: [ fresh_character(:aragorn), fresh_character(:aragorn_copy) ], seed: 77, max_rounds: 5).call
    end

    without, disabled = run.(with_disabled_gambits: false), run.(with_disabled_gambits: true)
    assert_equal without, disabled
  end

  test "gambits: a spell or feature fired by a gambit lands on the rule's target, not a random one" do
    cases = {
      spellcaster_with_known_spells(:merlin) => { action_kind: :spell, spell: spells(:fire_bolt) },
      player_characters(:barbarian_test_striker) => { action_kind: :class_feature, class_feature: class_features(:barbarian_test_save_strike) }
    }

    cases.each do |actor, action|
      (1..6).each do |seed|
        actor.gambits.reset
        sturdy(actor)
        # Only the middle enemy is at normal HP: still the weakest even if it heals itself before the actor's turn.
        enemies = %i[aragorn aragorn_copy elora].map { |name| fresh_character(name) }
        sturdy(enemies.first)
        sturdy(enemies.third)
        add_gambit(actor, position: 1, condition: :lowest_hp, **action)

        turn = actor_turns(actor:, result: simulator(party_one: [ actor ], party_two: enemies, seed:, max_rounds: 1).call).first

        assert_equal 1, turn.dig(:gambit, :position)
        assert_operator turn[:results].first[:hp_before], :<=, enemies.second.max_hit_points, "#{actor.name}, seed #{seed}: expected the weakest enemy as target"
      end
    end
  end

  test "gambits: choices driven by gambits never draw from the RNG" do
    seed = 9
    party_one = [ fresh_character(:aragorn), fresh_character(:fighter_archer) ]
    party_two = [ fresh_character(:aragorn_copy), fresh_character(:fighter_defender) ]
    (party_one + party_two).each do |character|
      add_gambit(character, position: 1, condition: :hp_below, condition_value: 50)
      add_gambit(character, position: 2, target: :self, condition: :hp_below, condition_value: 30, action_kind: :class_feature,
                                         class_feature: class_features(:fighter_second_wind))
      add_gambit(character, position: 3, condition: :lowest_hp)
    end
    simulation = simulator(party_one:, party_two:, seed:, max_rounds: 5)

    result = simulation.call

    assert result[:round_log].flat_map { |round| round[:turns] }.count { |turn| turn[:gambit] } > 4
    assert_equal Marshal.dump(Random.new(seed)), Marshal.dump(simulation.rng),
      "a gambit-driven turn must not consume the RNG"
  end

  test "gambits: an 'any' rule with several candidates never draws from the RNG" do
    seed = 9
    party_one = [ sturdy(fresh_character(:aragorn)), sturdy(fresh_character(:fighter_archer)) ]
    party_two = [ sturdy(fresh_character(:aragorn_copy)), sturdy(fresh_character(:fighter_defender)) ]
    (party_one + party_two).each { |character| add_gambit(character, position: 1) }
    simulation = simulator(party_one:, party_two:, seed:, max_rounds: 2)

    turns = simulation.call[:round_log].flat_map { |round| round[:turns] }

    # Level 1 fighters: no Action Surge, no War Magic, so every turn is a gambit turn against 2 living enemies.
    assert_equal [ "Inimigo: qualquer → Ataque" ] * 8, turns.map { |turn| turn.dig(:gambit, :rule) }
    assert_equal Marshal.dump(Random.new(seed)), Marshal.dump(simulation.rng),
      "an 'any' rule must not consume the RNG"
  end

  test "gambits: a spell rule casts its own spell, and falls to the next rule without a slot for it" do
    actor = sturdy(spellcaster_with_known_spells(:merlin))
    magic_missile = spells(:magic_missile)
    add_gambit(actor, position: 1, action_kind: :spell, spell: magic_missile)
    add_gambit(actor, position: 2)
    new_simulation = -> { gambit_simulation(actor:, enemy: sturdy(fresh_character(:aragorn))) }
    run = -> { actor_turns(actor:, result: new_simulation.call.call).first }

    first_spell = Combat::Participant.new(actor).action_options.find(&:spell?).spell
    assert_not_equal magic_missile, first_spell, "another spell must come first, or matching the rule's own spell is untested"

    turn = run.call
    assert_equal [ "magic-missile", 1 ], [ turn.dig(:action, :spell_slug), turn.dig(:gambit, :position) ]

    actor.define_singleton_method(:spell_slots) { { 1 => 0 } } # a sheet with no slot left
    turn = run.call
    assert_equal [ :attack, 2 ], [ turn.dig(:action, :type), turn.dig(:gambit, :position) ]
  end

  test "gambits: priority follows position, not creation order, and a reorder takes effect" do
    second_wind = class_features(:fighter_second_wind)
    actor = sturdy(player_characters(:aragorn))
    actor.gambits.load # already loaded, as after editing the rules: new records stay in creation order in memory
    attack = actor.gambits.create!(position: 2, target: :enemy, condition: :any, action_kind: :attack)
    heal = actor.gambits.create!(position: 1, target: :self, condition: :any, action_kind: :class_feature, class_feature: second_wind)
    assert_operator attack.id, :<, heal.id
    first_action = -> { actor_turns(actor:, result: gambit_simulation(actor:).call).first.dig(:action, :type) }

    assert_equal :class_feature, first_action.call

    Gambit.transaction do # the unique (owner, position) constraint is deferred, so a swap is allowed
      attack.update!(position: 1)
      heal.update!(position: 2)
    end
    sturdy(actor.reload)

    assert_equal :attack, first_action.call
  end

  test "gambits: a spell fired by a gambit spends exactly one slot" do
    actor = sturdy(spellcaster_with_known_spells(:merlin))
    assert_equal 2, actor.spell_slots[1]
    add_gambit(actor, position: 1, action_kind: :spell, spell: spells(:magic_missile))
    simulation = gambit_simulation(actor:, enemy: sturdy(fresh_character(:aragorn)))

    turns = actor_turns(actor:, result: simulation.call)

    assert_equal [ "magic-missile" ], turns.map { |turn| turn.dig(:action, :spell_slug) }
    assert_equal 1, participant_of(simulation, actor).available_spell_slots[1]
    assert_equal 2, actor.spell_slots[1], "the sheet keeps its slots"
  end

  test "gambits: a combat where every gambit turn stands idle never draws from the RNG" do
    seed = 9
    party_one = [ sturdy(fresh_character(:aragorn)) ]
    party_two = [ sturdy(fresh_character(:aragorn_copy)) ]
    (party_one + party_two).each { |character| add_gambit(character, position: 1, condition: :hp_below, condition_value: 10) }
    simulation = simulator(party_one:, party_two:, seed:, max_rounds: 3)

    turns = simulation.call[:round_log].flat_map { |round| round[:turns] }

    assert_equal [ { type: :idle } ] * 6, turns.map { |turn| turn[:action] }
    assert_equal Marshal.dump(Random.new(seed)), Marshal.dump(simulation.rng),
      "an idle turn must not consume the RNG"
  end

  test "gambits: an 'any' rule takes the first living candidate in initiative order, on every attack" do
    actor = sturdy(fresh_character(:thorin))
    actor.define_singleton_method(:attacks_per_action) { 20 }
    enemies = [ sturdy(fresh_character(:aragorn)), sturdy(fresh_character(:aragorn_copy)) ]
    add_gambit(actor, position: 1)
    simulation = simulator(party_one: [ actor ], party_two: enemies, seed: SEED_WITH_REVERSED_INITIATIVE, max_rounds: 1)

    turn = actor_turns(actor:, result: simulation.call).first

    order = simulation.encounter.initiative_order.map(&:id) - [ actor.combatant.id ]
    assert_equal enemies.reverse.map { it.combatant.id }, order, "the seed must put the enemies in initiative order opposite to their party order"
    assert_equal [ order.first ] * 20, turn[:results].map { |attack| attack[:target_id] }
  end

  test "gambits: a maneuver fired by a gambit rides an attack on the rule's target" do
    actor = battle_master_with_known_maneuvers(:battle_master_seven)
    (1..6).each do |seed|
      actor.gambits.reset
      sturdy(actor)
      enemies = [ sturdy(fresh_character(:aragorn)), fresh_character(:aragorn_copy), sturdy(fresh_character(:elora)) ]
      add_gambit(actor, position: 1, condition: :lowest_hp, action_kind: :class_feature,
                        class_feature: class_features(:fighter_battle_master_maneuver_precision_attack))

      turn = actor_turns(actor:, result: simulator(party_one: [ actor ], party_two: enemies, seed:, max_rounds: 1).call).first

      assert_equal "Maneuver: Precision Attack", turn.dig(:action, :riders, 0, :feature_name)
      assert_equal enemies.second.combatant.id, turn[:results].first[:target_id], "seed #{seed}: expected the weakest enemy as target"
    end
  end

  private

    def fresh_character(fixture_name)
      character = player_characters(fixture_name).dup
      character.id = player_characters(fixture_name).id
      character
    end

    # Uses the fixture record directly (no #dup): a has_many :through association like
    # #known_maneuvers only queries the database for a persisted owner, and .dup always
    # resets new_record? to true even after manually re-assigning the original id.
    def battle_master_with_known_maneuvers(fixture_name)
      player_characters(fixture_name)
    end

    # Uses the fixture record directly (no #dup), for the same reason as
    # #battle_master_with_known_maneuvers: #spells is a has_many :through
    # association, which only resolves for a persisted owner.
    def spellcaster_with_known_spells(fixture_name)
      player_characters(fixture_name)
    end

    # A fixture target with a chosen armor class and plenty of HP, so it survives a few hits and the
    # to-hit bonus alone decides whether an attack lands.
    def hittable_target(armor_class:)
      target = player_characters(:aragorn)
      target.combatant.update!(armor_class:, max_hit_points: 1000)
      target
    end

    # Before the first round (Combat::Simulator#call's block): a Distracting Strike mark from each source on
    # the target, and only the first one in the initiative order.
    def mark_and_play_first(encounter, target:, sources:, first:)
      marked = participant_of(encounter, target)
      sources.each do |source|
        marked.add_status(Combat::Status.new(kind: "next_attack_advantage", source: participant_of(encounter, source), ends: "source_turn_start"))
      end
      encounter.initiative_order = [ participant_of(encounter, first) ]
    end

    def add_gambit(character, position:, target: :enemy, condition: :any, action_kind: :attack, **attributes)
      character.gambits.build(position:, target:, condition:, action_kind:, **attributes)
    end

    # Starts with enough HP that nobody falls over the few rounds a gambit test runs.
    def sturdy(character)
      @hit_points[character.combatant.id] = 1000
      character
    end

    # The simulator, with the starting HP the test set.
    def simulator(**)
      Combat::Simulator.new(hit_points: @hit_points, **)
    end

    def gambit_simulation(actor:, enemy: sturdy(fresh_character(:merlin)), max_rounds: 1)
      simulator(party_one: [ actor ], party_two: [ enemy ], seed: 5, max_rounds:)
    end

    # The actor's own turn entries (not passives or Action Surge extras).
    def actor_turns(actor:, result:)
      result[:round_log].flat_map { |round| round[:turns] }
        .select { |turn| turn[:actor_id] == actor.combatant.id && turn.dig(:action, :type) != :turn_passive && !turn[:extra] }
    end
end
