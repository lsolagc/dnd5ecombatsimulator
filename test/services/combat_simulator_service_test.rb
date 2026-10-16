require "test_helper"
require "minitest/mock"

class CombatSimulatorServiceTest < ActiveSupport::TestCase
  SEED_WITH_REVERSED_INITIATIVE = 3
  test "returns the expected contract shape" do
    party_one = [ fresh_character(:aragorn) ]
    party_two = [ fresh_character(:aragorn_copy) ]

    result = CombatSimulatorService.new(party_one:, party_two:, seed: 1234, max_rounds: 3).call

    assert_includes result.keys, :winning_party
    assert_includes result.keys, :total_rounds
    assert_includes result.keys, :round_log
    assert_includes result.keys, :draw
    assert_includes result.keys, :outcome
    assert result[:round_log].is_a?(Array)
    assert result[:total_rounds] <= 3
  end

  test "is deterministic when using the same seed" do
    result_one = CombatSimulatorService.new(
      party_one: [ fresh_character(:thorin) ],
      party_two: [ fresh_character(:aragorn), fresh_character(:aragorn_copy) ],
      seed: 77,
      max_rounds: 5
    ).call

    result_two = CombatSimulatorService.new(
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
    name_of = %i[thorin fighter_archer aragorn aragorn_copy fighter_defender].index_by { |name| player_characters(name).id }

    result = CombatSimulatorService.new(party_one:, party_two:, seed: 77, max_rounds: 3).call

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
    name_of = { eldritch_knight.id => :eldritch_knight_seven, enemies.first.id => :aragorn, enemies.second.id => :aragorn_copy }

    result = CombatSimulatorService.new(party_one: [ eldritch_knight ], party_two: enemies, seed: 6, max_rounds: 3).call

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

  test "signals explicit draw on simultaneous elimination" do
    fallen_one = fresh_character(:aragorn)
    fallen_two = fresh_character(:aragorn_copy)
    fallen_one.current_hit_points = 0
    fallen_two.current_hit_points = 0

    result = CombatSimulatorService.new(
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
    service = CombatSimulatorService.new(
      party_one: [ fresh_character(:thorin) ],
      party_two: [ fresh_character(:aragorn) ],
      seed: 42,
      max_rounds: 5,
      abort_if: -> { (rounds_started += 1) > 1 }
    )

    assert_raises(CombatSimulatorService::Aborted) { service.call }
    assert_equal 2, rounds_started
  end

  test "weapon attack entries carry the target's HP before and after the hit" do
    target = fresh_character(:aragorn_copy)
    result = CombatSimulatorService.new(party_one: [ fresh_character(:thorin) ], party_two: [ target ], seed: 42, max_rounds: 3).call

    attacks = result[:round_log].flat_map { |round| round[:turns] }.flat_map { |turn| turn[:results] }.select { |entry| entry[:kind] == :attack }
    assert attacks.any?
    attacks.each do |attack|
      assert_operator attack[:hp_after], :<=, attack[:hp_before]
      assert_equal attack[:hp_before], attack[:hp_after] unless attack[:success]
    end
  end

  test "loads each combatant's unlocked features once per simulation, not on every turn" do
    party_one = [ fresh_character(:battle_master_seven) ]
    party_two = [ fresh_character(:eldritch_knight_seven), fresh_character(:champion_seven) ]

    unlock_lookups = 0
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      unlock_lookups += 1 if payload[:sql].include?('FROM "class_features" LEFT OUTER JOIN "class_feature_unlocks"')
    end
    result = CombatSimulatorService.new(party_one:, party_two:, seed: 3, max_rounds: 10).call
    ActiveSupport::Notifications.unsubscribe(subscription)

    assert_equal 10, result[:total_rounds], "the fight must be long enough for a per-turn lookup to show"
    # One lookup per combatant (PlayerCharacter#feature_unlocks, shared by the simulator and the passives),
    # however long the fight.
    assert_equal 3, unlock_lookups
  end

  test "an unlock without an effect inherits the one before it: the simulator, the resolver and the gambits all see it" do
    second_wind = class_features(:fighter_second_wind)
    ClassFeatureUnlock.create!(class_feature: second_wind, level: 10, uses: 2, description: "Test: one more use, same effect.")
    fighter = player_characters(:eldritch_knight_ten)

    service = CombatSimulatorService.new(party_one: [ fighter ], party_two: [ fresh_character(:aragorn) ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)
    action = service.send(:available_actions_for, actor: fighter).find { |candidate| candidate[:class_feature] == second_wind }
    assert_equal [ "heal", 2 ], [ action&.dig(:payload, "kind"), action&.dig(:uses_remaining) ]

    effects = Combat::EffectResolver.call(action: Combat::CombatAction.new(source_type: :class_feature, source_id: second_wind.id, actor: fighter))
    assert_equal [ "heal" ], effects.map(&:kind).map(&:to_s)

    assert_includes fighter.gambit_action_options, [ second_wind.name, "class_feature:#{second_wind.id}" ]
    assert Gambit.new(owner: fighter, position: 1, target: :self, condition: :any, action_kind: :class_feature, class_feature: second_wind).valid?
  end

  test "respects max_rounds stop condition" do
    result = CombatSimulatorService.new(
      party_one: [ fresh_character(:thorin) ],
      party_two: [ fresh_character(:aragorn) ],
      seed: 42,
      max_rounds: 1
    ).call

    assert_equal 1, result[:total_rounds]
  end

  test "Survivor heals a Champion at half HP or below at the start of their turn" do
    champion = fresh_character(:champion_eighteen)
    champion.current_hit_points = champion.max_hit_points / 2
    starting_hit_points = champion.current_hit_points

    result = CombatSimulatorService.new(
      party_one: [ champion ],
      party_two: [ fresh_character(:aragorn) ],
      seed: 99,
      max_rounds: 1
    ).call

    passive_entries = result[:round_log].flat_map { |round| round[:turns] }
      .select { |turn| turn[:actor_id] == champion.id && turn.dig(:action, :type) == :turn_passive && turn.dig(:action, :trigger) == "turn_start" }

    assert_equal 1, passive_entries.size
    assert_equal :heal, passive_entries.first[:results].first[:kind]
    assert_operator champion.current_hit_points, :>, starting_hit_points
  end

  test "a maneuver rides on a weapon attack: its die is added on a hit, spending one superiority die, and nothing on a miss" do
    battle_master = battle_master_with_known_maneuvers(:battle_master_seven)
    target = hittable_target(armor_class: 1)
    service = maneuver_service(battle_master:, target:)

    action = maneuver_action(service:, actor: battle_master, slug: "precision-attack")
    assert action, "expected Precision Attack to be available to a Battle Master who knows it"
    assert_equal 4, action[:uses_remaining]

    Random.srand(1)
    turn = service.send(:execute_action, actor: battle_master, chosen_action: action, round_number: 1, turn_index: 1)

    assert_equal :attack, turn.dig(:action, :type)
    assert_equal "Maneuver: Precision Attack", turn.dig(:action, :maneuver_name)
    attack = turn[:results].first
    assert attack[:success]
    assert_equal :damage, attack.dig(:rider, :kind)
    assert_includes 1..8, attack.dig(:rider, :amount)
    assert_equal 3, maneuver_action(service:, actor: battle_master, slug: "precision-attack")[:uses_remaining]

    target.combatant.update!(armor_class: 100)
    Random.srand(1)
    miss = service.send(:execute_action, actor: battle_master, chosen_action: action, round_number: 1, turn_index: 1).dig(:results, 0)

    assert_not miss[:success]
    assert_nil miss[:rider]
    assert_equal 3, maneuver_action(service:, actor: battle_master, slug: "precision-attack")[:uses_remaining], "a miss must not spend a die"

    combat_superiority_id = class_features(:fighter_battle_master_combat_superiority).id
    service.send(:instance_variable_get, :@uses_remaining)[battle_master.id][combat_superiority_id] = 0

    assert_nil maneuver_action(service:, actor: battle_master, slug: "precision-attack")
  end

  test "Distracting Strike marks the target only when the attack hits, and the mark is spent by the first other attacker" do
    battle_master = battle_master_with_known_maneuvers(:battle_master_seven)
    ally = fresh_character(:aragorn_copy)
    target = hittable_target(armor_class: 100)
    service = maneuver_service(battle_master:, target:, allies: [ ally ])
    marks = service.send(:instance_variable_get, :@advantage_marks)
    strike = maneuver_action(service:, actor: battle_master, slug: "distracting-strike")
    strike_now = -> { service.send(:execute_action, actor: battle_master, chosen_action: strike, round_number: 1, turn_index: 1) }
    attack_now = ->(actor) { service.send(:execute_attack_action, actor:, round_number: 1, turn_index: 1).dig(:results, 0) }

    Random.srand(1) # AC 100: a miss
    assert_not strike_now.call.dig(:results, 0, :success)
    assert_empty marks[target.id], "no hit, no mark"

    target.combatant.update!(armor_class: 1)
    Random.srand(1)
    assert strike_now.call.dig(:results, 0, :success)
    assert_equal [ battle_master.id ], marks[target.id]

    assert_not attack_now.(battle_master)[:advantage], "the mark never helps the one who set it"
    assert_equal [ battle_master.id ], marks[target.id]

    assert attack_now.(ally)[:advantage], "the next attack by anyone else has advantage"
    assert_empty marks[target.id]
    assert_not attack_now.(ally)[:advantage], "the mark is consumed by that one attack"
  end

  test "a Distracting Strike mark expires at the start of its owner's next turn, leaving other owners' marks alone" do
    battle_master = battle_master_with_known_maneuvers(:battle_master_seven)
    ally = fresh_character(:aragorn_copy)
    target = hittable_target(armor_class: 1)
    service = maneuver_service(battle_master:, target:, allies: [ ally ])
    marks = service.send(:instance_variable_get, :@advantage_marks)
    marks[target.id] = [ ally.id, battle_master.id ]
    target.current_hit_points = 0 # the fight is over, so the turn ends right after the expiry and no attack spends a mark

    service.send(:execute_round, round_number: 1, initiative_order: [ battle_master ])

    assert_equal [ ally.id ], marks[target.id]
  end

  test "a Battle Master who does not know Precision Attack does not see it as an available action" do
    battle_master = battle_master_with_known_maneuvers(:battle_master_seven)
    battle_master.player_character_maneuvers.destroy_all

    service = CombatSimulatorService.new(party_one: [ battle_master ], party_two: [ fresh_character(:aragorn) ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    assert_nil precision_attack_action(service:, actor: battle_master)
  end

  test "Action Surge grants an extra action on the same turn and respects the uses limit" do
    actor = fresh_character(:fighter_no_archetype_seven)
    service = CombatSimulatorService.new(party_one: [ actor ], party_two: [ fresh_character(:aragorn_copy) ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    # Second Wind is otherwise available at this level; disable it so the extra action
    # deterministically resolves to a plain attack (only remaining option).
    uses_remaining = service.send(:instance_variable_get, :@uses_remaining)
    uses_remaining[actor.id][class_features(:fighter_second_wind).id] = 0

    action_surge_id = class_features(:fighter_action_surge).id
    assert_equal 1, uses_remaining[actor.id][action_surge_id]

    Random.srand(1)
    extra_turn = service.send(:action_surge_turn, actor: actor, round_number: 1, turn_index: 1)

    assert extra_turn, "expected Action Surge to grant an extra action"
    assert_equal true, extra_turn[:extra]
    assert_equal :attack, extra_turn.dig(:action, :type)
    assert_equal 0, uses_remaining[actor.id][action_surge_id]

    assert_nil service.send(:action_surge_turn, actor: actor, round_number: 1, turn_index: 2)
  end

  test "Indomitable rerolls a failed saving throw against the fighter and consumes a use" do
    fighter = player_characters(:fighter_indomitable_nine) # constitution: 12 (mod +1)
    attacker = player_characters(:barbarian_test_striker)

    service = CombatSimulatorService.new(party_one: [ attacker ], party_two: [ fighter ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    chosen_action = service.send(:available_actions_for, actor: attacker).find do |action|
      action[:type] == :class_feature && action[:class_feature].slug == "test-save-strike"
    end
    assert chosen_action, "expected the test save-strike fixture to be available to the attacker"

    indomitable_id = class_features(:fighter_indomitable).id
    uses_remaining = service.send(:instance_variable_get, :@uses_remaining)
    assert_equal 1, uses_remaining[fighter.id][indomitable_id]

    Random.srand(46) # 1d6 roll = 6; 1st constitution save total 7 (fails dc 8); reroll total 10 (succeeds)
    turn = service.send(:execute_class_feature_action, actor: attacker, chosen_action: chosen_action, round_number: 1, turn_index: 1)

    damage_result = turn[:results].first
    assert_equal :damage, damage_result[:kind]
    assert_equal 3, damage_result[:amount] # half of 6, since the reroll succeeded

    assert_equal 0, uses_remaining[fighter.id][indomitable_id]
  end

  test "an Eldritch Knight autonomously casts a spell during a simulated round" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven)
    target = fresh_character(:aragorn)

    result = CombatSimulatorService.new(party_one: [ caster ], party_two: [ target ], seed: 2, max_rounds: 1).call

    cast_turn = result[:round_log].flat_map { |round| round[:turns] }
      .find { |turn| turn[:actor_id] == caster.id && turn.dig(:action, :type) == :cast_spell }

    assert cast_turn, "expected the Eldritch Knight to autonomously cast a spell"
    assert_equal "magic-missile", cast_turn.dig(:action, :spell_slug)
    assert_equal :damage, cast_turn[:results].first[:kind]
    assert_equal 12, cast_turn[:results].first[:amount]
  end

  test "choose_turn_action picks the physical branch when the coin flip favors it" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven)
    service = CombatSimulatorService.new(party_one: [ caster ], party_two: [ fresh_character(:aragorn) ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    available = service.send(:available_actions_for, actor: caster)
    chosen = service.send(:choose_turn_action, available:, actor: caster)

    assert_equal :attack, chosen[:type]
  end

  test "choose_turn_action picks the spell branch when the coin flip favors it" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven)
    service = CombatSimulatorService.new(party_one: [ caster ], party_two: [ fresh_character(:aragorn) ], seed: 3, max_rounds: 1)
    service.send(:initialize_state)

    available = service.send(:available_actions_for, actor: caster)
    chosen = service.send(:choose_turn_action, available:, actor: caster)

    assert_equal :cast_spell, chosen[:type]
    assert_equal "magic-missile", chosen[:spell].slug
  end

  test "choose_turn_action does not consume extra randomness for a non-spellcasting actor" do
    # Comparing only the chosen action is not a reliable regression guard: for some
    # seeds/list sizes, an extra @rng draw before the real sample still lands on the
    # same element by coincidence. Compare the RNG's internal state instead, which only
    # matches if the exact same sequence of draws happened.
    actor = fresh_character(:aragorn)
    plain_service = CombatSimulatorService.new(party_one: [ actor ], party_two: [ fresh_character(:aragorn_copy) ], seed: 5, max_rounds: 1)
    heuristic_service = CombatSimulatorService.new(party_one: [ actor ], party_two: [ fresh_character(:aragorn_copy) ], seed: 5, max_rounds: 1)

    available = plain_service.send(:available_actions_for, actor: actor)
    plain_rng = plain_service.send(:instance_variable_get, :@rng)
    heuristic_rng = heuristic_service.send(:instance_variable_get, :@rng)

    available.sample(random: plain_rng)
    heuristic_service.send(:choose_turn_action, available:, actor: actor)

    assert_equal Marshal.dump(plain_rng), Marshal.dump(heuristic_rng),
      "choose_turn_action must consume @rng identically to a single available.sample(random: @rng) call"
  end

  test "cast_spell action disappears from available_actions_for once its spell slot is exhausted" do
    wizard = spellcaster_with_known_spells(:merlin)
    service = CombatSimulatorService.new(party_one: [ wizard ], party_two: [ fresh_character(:aragorn) ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    cast_slugs = service.send(:available_actions_for, actor: wizard)
      .select { |action| action[:type] == :cast_spell }
      .map { |action| action[:spell].slug }
    assert_includes cast_slugs, "magic-missile"
    assert_includes cast_slugs, "fire-bolt"

    wizard.available_spell_slots[1] = 0

    remaining_cast_slugs = service.send(:available_actions_for, actor: wizard)
      .select { |action| action[:type] == :cast_spell }
      .map { |action| action[:spell].slug }
    assert_not_includes remaining_cast_slugs, "magic-missile"
    assert_includes remaining_cast_slugs, "fire-bolt" # cantrips never consume a slot
  end

  test "non integer uses values are floored" do
    service = CombatSimulatorService.new(
      party_one: [ fresh_character(:merlin) ],
      party_two: [ fresh_character(:aragorn_copy) ]
    )

    assert_equal 2, service.send(:normalize_uses_value, 2.9)
    assert_equal 0, service.send(:normalize_uses_value, 0.8)
  end

  test "War Magic grants a bonus weapon attack when the turn's normal action casts a cantrip" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven)
    service = CombatSimulatorService.new(party_one: [ caster ], party_two: [ fresh_character(:aragorn) ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    chosen_action = service.send(:available_actions_for, actor: caster).find do |action|
      action[:type] == :cast_spell && action[:spell].slug == "fire-bolt"
    end
    assert chosen_action, "expected fire-bolt (a cantrip) to be an available action"

    Random.srand(1)
    bonus_turn = service.send(:war_magic_turn, actor: caster, chosen_action:, round_number: 1, turn_index: 1)

    assert bonus_turn, "expected War Magic to grant a bonus weapon attack"
    assert_equal true, bonus_turn[:bonus]
    assert_equal :attack, bonus_turn.dig(:action, :type)
  end

  test "War Magic does not grant a bonus attack for a non-cantrip spell before Improved War Magic" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven)
    chosen_action = { type: :cast_spell, spell: spells(:magic_missile) }
    service = CombatSimulatorService.new(party_one: [ caster ], party_two: [ fresh_character(:aragorn) ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    assert_nil service.send(:war_magic_turn, actor: caster, chosen_action:, round_number: 1, turn_index: 1)
  end

  test "Improved War Magic grants a bonus weapon attack even for a non-cantrip spell" do
    caster = spellcaster_with_known_spells(:eldritch_knight_eighteen)
    service = CombatSimulatorService.new(party_one: [ caster ], party_two: [ fresh_character(:aragorn) ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    chosen_action = service.send(:available_actions_for, actor: caster).find do |action|
      action[:type] == :cast_spell && action[:spell].slug == "magic-missile"
    end
    assert chosen_action, "expected magic-missile to be an available action"

    Random.srand(1)
    bonus_turn = service.send(:war_magic_turn, actor: caster, chosen_action:, round_number: 1, turn_index: 1)

    assert bonus_turn, "expected Improved War Magic to grant a bonus weapon attack for a non-cantrip spell"
    assert_equal true, bonus_turn[:bonus]
    assert_equal :attack, bonus_turn.dig(:action, :type)
  end

  test "a successful weapon attack from an Eldritch Knight with Eldritch Strike marks the target as pending" do
    caster = spellcaster_with_known_spells(:eldritch_knight_ten)
    target = fresh_character(:aragorn)

    service = CombatSimulatorService.new(party_one: [ caster ], party_two: [ target ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)

    Random.srand(1)
    turn = service.send(:execute_attack_action, actor: caster, round_number: 1, turn_index: 1)

    assert_equal true, turn[:results].first[:success], "expected the attack to hit (attack_bonus is set high for determinism)"
    pending = service.send(:instance_variable_get, :@eldritch_strike_pending)
    assert_equal caster.id, pending[target.id]
  end

  test "Eldritch Strike imposes disadvantage on the target's next save against the same caster's spell, then stops" do
    caster = spellcaster_with_known_spells(:eldritch_knight_ten)
    target = fresh_character(:aragorn) # dexterity 12 (mod +1)

    service = CombatSimulatorService.new(party_one: [ caster ], party_two: [ target ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)
    service.send(:instance_variable_get, :@eldritch_strike_pending)[target.id] = caster.id

    chosen_action = service.send(:available_actions_for, actor: caster).find do |action|
      action[:type] == :cast_spell && action[:spell].slug == "test-save-spell"
    end
    assert chosen_action, "expected test-save-spell to be an available action"

    # seed 4: 1d6 damage roll = 3; disadvantage keeps the worse of two d20 saves
    # (+1 dexterity modifier) = total 7, failing DC 8 -> full damage (3).
    Random.srand(4)
    first_turn = service.send(:execute_cast_spell_action, actor: caster, chosen_action:, round_number: 1, turn_index: 1)
    assert_equal 3, first_turn[:results].first[:amount], "expected disadvantage to cause the save to fail (full damage)"

    pending = service.send(:instance_variable_get, :@eldritch_strike_pending)
    assert_nil pending[target.id], "expected the Eldritch Strike mark to be consumed by the first save"

    # Same seed, no pending mark this time: only one d20 is rolled (total 16), the save
    # succeeds against DC 8, halving the damage (3 / 2 = 1).
    Random.srand(4)
    second_turn = service.send(:execute_cast_spell_action, actor: caster, chosen_action:, round_number: 1, turn_index: 2)
    assert_equal 1, second_turn[:results].first[:amount], "expected the second save, without disadvantage, to succeed and halve damage"
  end

  test "Eldritch Strike's disadvantage does not leak to a different attacker or a different target" do
    marked_target = fresh_character(:aragorn) # dexterity 12 (mod +1)

    # A different attacker must not benefit from someone else's mark on the target.
    other_caster = spellcaster_with_known_spells(:eldritch_knight_eighteen)
    attacker_leak_service = CombatSimulatorService.new(party_one: [ other_caster ], party_two: [ marked_target ], seed: 1, max_rounds: 1)
    attacker_leak_service.send(:initialize_state)
    attacker_leak_service.send(:instance_variable_get, :@eldritch_strike_pending)[marked_target.id] = player_characters(:eldritch_knight_ten).id

    other_action = attacker_leak_service.send(:available_actions_for, actor: other_caster).find do |action|
      action[:type] == :cast_spell && action[:spell].slug == "test-save-spell"
    end
    assert other_action, "expected test-save-spell to be available to the other caster"

    # Same seed/roll math as the sibling test's "no disadvantage" branch: a single d20
    # save succeeds, halving damage -> a different attacker never gets the disadvantage.
    Random.srand(4)
    leaked_turn = attacker_leak_service.send(:execute_cast_spell_action, actor: other_caster, chosen_action: other_action, round_number: 1, turn_index: 1)
    assert_equal 1, leaked_turn[:results].first[:amount], "a different attacker must not receive the marked target's disadvantage"

    # The same attacker must not get disadvantage against a target they haven't marked.
    marker = spellcaster_with_known_spells(:eldritch_knight_ten)
    unmarked_target = fresh_character(:aragorn_copy)
    target_leak_service = CombatSimulatorService.new(party_one: [ marker ], party_two: [ unmarked_target ], seed: 1, max_rounds: 1)
    target_leak_service.send(:initialize_state)
    target_leak_service.send(:instance_variable_get, :@eldritch_strike_pending)[marked_target.id] = marker.id # a mark on someone else entirely

    marker_action = target_leak_service.send(:available_actions_for, actor: marker).find do |action|
      action[:type] == :cast_spell && action[:spell].slug == "test-save-spell"
    end
    assert marker_action, "expected test-save-spell to be available to the marking attacker"

    Random.srand(4)
    unmarked_turn = target_leak_service.send(:execute_cast_spell_action, actor: marker, chosen_action: marker_action, round_number: 1, turn_index: 1)
    assert_equal 1, unmarked_turn[:results].first[:amount], "the same attacker casting against an unmarked target must not get disadvantage"
  end

  test "war_magic_available? and eldritch_strike_unlocked? never consume @rng" do
    # Both are queried on every actor's turn/attack (not just Eldritch Knights), so any
    # accidental @rng draw here would desync every other seeded test in the suite.
    actor = fresh_character(:aragorn) # no spellcasting, no Eldritch Knight features
    service = CombatSimulatorService.new(party_one: [ actor ], party_two: [ fresh_character(:aragorn_copy) ], seed: 5, max_rounds: 1)
    service.send(:initialize_state)
    rng = service.send(:instance_variable_get, :@rng)

    before = Marshal.dump(rng)
    service.send(:war_magic_available?, actor: actor, chosen_action: { type: :attack })
    service.send(:eldritch_strike_unlocked?, actor: actor)
    after = Marshal.dump(rng)

    assert_equal before, after, "availability checks for War Magic/Eldritch Strike must never consume @rng"
  end

  test "serialized results carry the spell attack roll only when the effect made one" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven) # proficiency +2 (no progression), INT 10 (+0)
    target = player_characters(:aragorn)
    target.combatant.update!(armor_class: 100)
    target.current_hit_points = target.max_hit_points
    service = CombatSimulatorService.new(party_one: [ caster ], party_two: [ target ], seed: 1, max_rounds: 1)

    attack_effect = Combat::EffectInstance.new(kind: :damage, roll_expression: "1d10", target_type: "target", attack: "spell")
    plain_effect = Combat::EffectInstance.new(kind: :damage, roll_expression: "1d10", target_type: "target")
    Random.srand(2) # first d20 = 9: neither an auto-hit nor an auto-miss against AC 100
    results = [ attack_effect, plain_effect ].map { |effect| Combat::EffectExecutor.call(effect:, actor: caster, target:) }

    with_attack, without_attack = service.send(:serialize_effect_results, results:)

    assert_equal({ natural: with_attack.dig(:attack_roll, :natural), total: with_attack.dig(:attack_roll, :natural) + 2,
                   armor_class: 100, hit: false, crit: with_attack.dig(:attack_roll, :natural) == 20 }, with_attack[:attack_roll])
    assert_not_includes without_attack.keys, :attack_roll
  end

  test "a feature's target kind restricts who it may pick: enemy never self or allies, ally never enemies" do
    actor = fresh_character(:aragorn)
    ally = fresh_character(:aragorn_copy)
    enemies = [ fresh_character(:merlin), fresh_character(:elora) ]
    service = CombatSimulatorService.new(party_one: [ actor, ally ], party_two: enemies, seed: 1)

    picks = ->(target) { 50.times.map { service.send(:resolve_feature_target, actor:, payload: { "target" => target }) }.uniq }

    assert_empty picks.("enemy") - enemies
    assert_empty picks.("ally") - [ actor, ally ]
    assert_equal [ actor ], picks.("self")
    assert_raises(ArgumentError) { picks.("target") }
  end

  test "an enemy-targeted feature has no target once every enemy is down" do
    actor = fresh_character(:aragorn)
    downed = fresh_character(:merlin)
    downed.current_hit_points = 0
    service = CombatSimulatorService.new(party_one: [ actor ], party_two: [ downed ], seed: 1)

    assert_nil service.send(:resolve_feature_target, actor:, payload: { "target" => "enemy" })
  end

  test "gambits: with two valid rules the top one wins, and a rule out of uses is skipped" do
    second_wind = class_features(:fighter_second_wind)
    actor = sturdy(fresh_character(:aragorn))
    add_gambit(actor, position: 1, target: :self, action_kind: :class_feature, class_feature: second_wind)
    add_gambit(actor, position: 2)

    turns = actor_turns(actor:, result: gambit_service(actor:, max_rounds: 2).call)

    assert_equal [ :class_feature, :attack ], turns.map { |turn| turn.dig(:action, :type) }
    assert_equal({ position: 1, rule: "Self: qualquer → Second Wind" }, turns.first[:gambit])
    assert_equal({ position: 2, rule: "Inimigo: qualquer → Ataque" }, turns.second[:gambit])
  end

  test "gambits: a rule whose condition finds no target is skipped and the next one fires" do
    actor = sturdy(fresh_character(:aragorn))
    add_gambit(actor, position: 1, condition: :hp_below, condition_value: 10)
    add_gambit(actor, position: 2, target: :self, action_kind: :class_feature, class_feature: class_features(:fighter_second_wind))

    turn = actor_turns(actor:, result: gambit_service(actor:).call).first

    assert_equal "second-wind", turn.dig(:action, :feature_slug)
    assert_equal 2, turn.dig(:gambit, :position)
  end

  test "gambits: a rule with a maneuver the character does not know is skipped" do
    precision = class_features(:fighter_battle_master_maneuver_precision_attack)
    actor = battle_master_with_known_maneuvers(:battle_master_seven)
    actor.player_character_maneuvers.where(maneuver: precision).destroy_all
    add_gambit(actor, position: 1, action_kind: :class_feature, class_feature: precision)
    add_gambit(actor, position: 2, action_kind: :class_feature, class_feature: class_features(:fighter_battle_master_maneuver_distracting_strike))

    turn = actor_turns(actor:, result: gambit_service(actor:).call).first

    assert_equal "Maneuver: Distracting Strike", turn.dig(:action, :maneuver_name)
    assert_equal 2, turn.dig(:gambit, :position)
  end

  test "gambits: when no rule fires the character stands idle" do
    actor = sturdy(fresh_character(:aragorn))
    enemy = sturdy(fresh_character(:merlin))
    add_gambit(actor, position: 1, condition: :hp_below, condition_value: 10)

    result = gambit_service(actor:, enemy:).call
    turns = actor_turns(actor:, result:)

    assert_equal [ { type: :idle } ], turns.map { |turn| turn[:action] }
    assert_equal [], turns.first[:results]
    assert_equal 1000, enemy.current_hit_points
    assert_nothing_raised { SimulationRun.metrics(result[:round_log]) }
  end

  test "gambits: lowest HP picks the weakest enemy, ties going to initiative order" do
    run = lambda do |weaken: nil|
      actor = sturdy(fresh_character(:thorin))
      enemies = [ fresh_character(:aragorn), fresh_character(:aragorn_copy) ]
      enemies.find { |enemy| enemy.id == weaken }&.then { |enemy| enemy.current_hit_points -= 5 }
      add_gambit(actor, position: 1, condition: :lowest_hp)
      service = CombatSimulatorService.new(party_one: [ actor ], party_two: enemies, seed: SEED_WITH_REVERSED_INITIATIVE, max_rounds: 1)
      first_target = actor_turns(actor:, result: service.call).first[:results].first[:target_id]
      [ first_target, service.instance_variable_get(:@initiative_order).map(&:id) - [ actor.id ] ]
    end

    target, order = run.call
    assert_equal [ player_characters(:aragorn_copy).id, player_characters(:aragorn).id ], order,
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
      CombatSimulatorService.new(party_one:, party_two:, seed: 77, max_rounds: 3).call
    end

    first = run.call
    second = run.call
    gambit_turns = first[:round_log].flat_map { |round| round[:turns] }.select { |turn| turn[:gambit] }
    positions = gambit_turns.map { |turn| turn.dig(:gambit, :position) }

    assert_operator positions.uniq.size, :>=, 2
    assert_equal 6, gambit_turns.map { |turn| turn[:actor_id] }.uniq.size
    assert_equal [ 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1 ], positions
    assert_equal first, second
  end

  test "gambits: the result opens with each side's rules, enabled or not, in priority order, and its mode" do
    actor = fresh_character(:aragorn)
    add_gambit(actor, position: 2, enabled: false)
    add_gambit(actor, position: 1, target: :self, action_kind: :class_feature, class_feature: class_features(:fighter_second_wind))
    all_disabled = fresh_character(:thorin)
    add_gambit(all_disabled, position: 1, condition: :hp_below, condition_value: 50, enabled: false)
    without_rules = fresh_character(:aragorn_copy)

    result = CombatSimulatorService.new(party_one: [ actor, all_disabled ], party_two: [ without_rules ], seed: 1, max_rounds: 1).call

    assert_equal :gambits, result.keys.first
    assert_equal({
      party_one: [
        { id: actor.id, name: "Aragorn", mode: "gambits", rules: [
          { position: 1, enabled: true, target: "Self", condition: "qualquer", action: "Second Wind", rule: "Self: qualquer → Second Wind" },
          { position: 2, enabled: false, target: "Inimigo", condition: "qualquer", action: "Ataque", rule: "Inimigo: qualquer → Ataque" }
        ] },
        { id: all_disabled.id, name: "Thorin", mode: "aleatório", rules: [
          { position: 1, enabled: false, target: "Inimigo", condition: "HP < 50%", action: "Ataque", rule: "Inimigo: HP < 50% → Ataque" }
        ] }
      ],
      party_two: [ { id: without_rules.id, name: "Aragorn Copy", mode: "aleatório", rules: [] } ]
    }, result[:gambits])
  end

  test "gambits: given a copy of the rules, the simulation plays and logs the copy, not the combatant's own gambits" do
    actor = sturdy(fresh_character(:aragorn))
    add_gambit(actor, position: 1) # its own rule: an attack
    second_wind = Gambit.new(position: 1, target: :self, condition: :any, action_kind: :class_feature, class_feature: class_features(:fighter_second_wind))
    disabled = Gambit.new(position: 2, target: :enemy, condition: :any, action_kind: :attack, enabled: false)
    copy = { actor.id.to_s => [ disabled.snapshot, second_wind.snapshot.merge("label" => "rótulo da cópia") ] }

    result = CombatSimulatorService.new(party_one: [ actor ], party_two: [ sturdy(fresh_character(:merlin)) ], seed: 5, max_rounds: 1, gambits: copy).call

    turn = actor_turns(actor:, result:).first
    assert_equal [ :class_feature, { position: 1, rule: "rótulo da cópia" } ], [ turn.dig(:action, :type), turn[:gambit] ]
    assert_equal [ [ 1, true, "rótulo da cópia" ], [ 2, false, "Inimigo: qualquer → Ataque" ] ],
                 result.dig(:gambits, :party_one, 0, :rules).map { |rule| rule.values_at(:position, :enabled, :rule) }
    assert_equal({ mode: "aleatório", rules: [] }, result.dig(:gambits, :party_two, 0).slice(:mode, :rules), "a combatant missing from the copy has no rules")
  end

  test "without gambits, every decision entry is logged as random, Action Surge's extra and the War Magic bonus included" do
    eldritch_knight = sturdy(spellcaster_with_known_spells(:eldritch_knight_seven))
    enemies = %i[aragorn aragorn_copy].map { |name| sturdy(fresh_character(name)) }

    entries = CombatSimulatorService.new(party_one: [ eldritch_knight ], party_two: enemies, seed: 6, max_rounds: 3).call[:round_log].flat_map { |round| round[:turns] }

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
      CombatSimulatorService.new(party_one: [ actor ], party_two: [ fresh_character(:aragorn), fresh_character(:aragorn_copy) ], seed: 77, max_rounds: 5).call
    end

    without, disabled = run.(with_disabled_gambits: false), run.(with_disabled_gambits: true)
    # Only the gambits section differs: it lists the disabled rules, still in "aleatório" mode.
    assert_equal without.except(:gambits), disabled.except(:gambits)
    assert_equal [ "aleatório", [ false, false ] ], disabled.dig(:gambits, :party_one, 0).then { |entry| [ entry[:mode], entry[:rules].pluck(:enabled) ] }
  end

  test "gambits: a feature fired by a gambit spends exactly one use" do
    second_wind = class_features(:fighter_second_wind)
    actor = sturdy(fresh_character(:aragorn))
    add_gambit(actor, position: 1, target: :self, action_kind: :class_feature, class_feature: second_wind)
    service = gambit_service(actor:)
    service.send(:initialize_state)
    service.instance_variable_set(:@initiative_order, [ actor, *service.instance_variable_get(:@party_two) ])
    uses_remaining = service.instance_variable_get(:@uses_remaining)
    uses_remaining[actor.id][second_wind.id] = 3

    turns = service.send(:execute_round, round_number: 1, initiative_order: service.instance_variable_get(:@initiative_order))

    assert_equal 1, turns.count { |turn| turn[:actor_id] == actor.id && turn.dig(:action, :feature_slug) == "second-wind" }
    assert_equal 2, uses_remaining[actor.id][second_wind.id]
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

        turn = actor_turns(actor:, result: CombatSimulatorService.new(party_one: [ actor ], party_two: enemies, seed:, max_rounds: 1).call).first

        assert_equal 1, turn.dig(:gambit, :position)
        assert_operator turn[:results].first[:hp_before], :<=, enemies.second.max_hit_points, "#{actor.name}, seed #{seed}: expected the weakest enemy as target"
      end
    end
  end

  test "gambits: each extra attack re-runs the rule, then falls back to the first living enemy in initiative order" do
    actor = fresh_character(:thorin)
    actor.define_singleton_method(:attacks_per_action) { 3 }
    enemies = %i[aragorn aragorn_copy elora fighter_archer fighter_defender].map { |name| fresh_character(name) }
    a, b, c, d, e = enemies
    a.current_hit_points = d.current_hit_points = 5 # below 50%: the rule's only candidates
    enemies.each { |enemy| enemy.define_singleton_method(:take_damage) { |**| self.current_hit_points = 0 } }
    gambit = add_gambit(actor, position: 1, condition: :hp_below, condition_value: 50)
    service = CombatSimulatorService.new(party_one: [ actor ], party_two: enemies, seed: 1, max_rounds: 1)
    service.send(:initialize_state)
    service.instance_variable_set(:@initiative_order, [ e, actor, c, a, d, b ])

    turn = Dice.stub(:hit?, true) { service.send(:execute_attack_action, actor:, round_number: 1, turn_index: 1, gambit:) } # every attack hits and kills

    # a and d by the rule (in initiative order), then e: the first living enemy in initiative order
    # (not b, the first in party order).
    assert_equal [ a.id, d.id, e.id ], turn[:results].map { |attack| attack[:target_id] }
  end

  test "gambits: choices driven by gambits never draw from @rng" do
    seed = 9
    party_one = [ fresh_character(:aragorn), fresh_character(:fighter_archer) ]
    party_two = [ fresh_character(:aragorn_copy), fresh_character(:fighter_defender) ]
    (party_one + party_two).each do |character|
      add_gambit(character, position: 1, condition: :hp_below, condition_value: 50)
      add_gambit(character, position: 2, target: :self, condition: :hp_below, condition_value: 30, action_kind: :class_feature,
                                         class_feature: class_features(:fighter_second_wind))
      add_gambit(character, position: 3, condition: :lowest_hp)
    end
    service = CombatSimulatorService.new(party_one:, party_two:, seed:, max_rounds: 5)

    result = service.call

    assert result[:round_log].flat_map { |round| round[:turns] }.count { |turn| turn[:gambit] } > 4
    assert_equal Marshal.dump(Random.new(seed)), Marshal.dump(service.instance_variable_get(:@rng)),
      "a gambit-driven turn must not consume @rng"
  end

  test "gambits: an 'any' rule with several candidates never draws from @rng" do
    seed = 9
    party_one = [ sturdy(fresh_character(:aragorn)), sturdy(fresh_character(:fighter_archer)) ]
    party_two = [ sturdy(fresh_character(:aragorn_copy)), sturdy(fresh_character(:fighter_defender)) ]
    (party_one + party_two).each { |character| add_gambit(character, position: 1) }
    service = CombatSimulatorService.new(party_one:, party_two:, seed:, max_rounds: 2)

    turns = service.call[:round_log].flat_map { |round| round[:turns] }

    # Level 1 fighters: no Action Surge, no War Magic, so every turn is a gambit turn against 2 living enemies.
    assert_equal [ "Inimigo: qualquer → Ataque" ] * 8, turns.map { |turn| turn.dig(:gambit, :rule) }
    assert_equal Marshal.dump(Random.new(seed)), Marshal.dump(service.instance_variable_get(:@rng)),
      "an 'any' rule must not consume @rng"
  end

  test "gambits: a spell rule casts its own spell, and falls to the next rule without a slot for it" do
    actor = sturdy(spellcaster_with_known_spells(:merlin))
    magic_missile = spells(:magic_missile)
    add_gambit(actor, position: 1, action_kind: :spell, spell: magic_missile)
    add_gambit(actor, position: 2)
    new_service = -> { gambit_service(actor:, enemy: sturdy(fresh_character(:aragorn))) }
    run = -> { actor_turns(actor:, result: new_service.call.call).first }

    service = new_service.call
    service.send(:initialize_state)
    first_spell = service.send(:available_actions_for, actor:).find { |action| action[:type] == :cast_spell }[:spell]
    assert_not_equal magic_missile, first_spell, "another spell must come first, or matching the rule's own spell is untested"

    turn = run.call
    assert_equal [ "magic-missile", 1 ], [ turn.dig(:action, :spell_slug), turn.dig(:gambit, :position) ]

    actor.available_spell_slots = { 1 => 0 }
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
    first_action = -> { actor_turns(actor:, result: gambit_service(actor:).call).first.dig(:action, :type) }

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
    actor.available_spell_slots = { 1 => 2 }
    add_gambit(actor, position: 1, action_kind: :spell, spell: spells(:magic_missile))

    turns = actor_turns(actor:, result: gambit_service(actor:, enemy: sturdy(fresh_character(:aragorn))).call)

    assert_equal [ "magic-missile" ], turns.map { |turn| turn.dig(:action, :spell_slug) }
    assert_equal({ 1 => 1 }, actor.available_spell_slots)
  end

  test "gambits: a combat where every gambit turn stands idle never draws from @rng" do
    seed = 9
    party_one = [ sturdy(fresh_character(:aragorn)) ]
    party_two = [ sturdy(fresh_character(:aragorn_copy)) ]
    (party_one + party_two).each { |character| add_gambit(character, position: 1, condition: :hp_below, condition_value: 10) }
    service = CombatSimulatorService.new(party_one:, party_two:, seed:, max_rounds: 3)

    turns = service.call[:round_log].flat_map { |round| round[:turns] }

    assert_equal [ { type: :idle } ] * 6, turns.map { |turn| turn[:action] }
    assert_equal Marshal.dump(Random.new(seed)), Marshal.dump(service.instance_variable_get(:@rng)),
      "an idle turn must not consume @rng"
  end

  test "gambits: a maneuver fired by a gambit spends exactly one superiority die on a hit" do
    battle_master = battle_master_with_known_maneuvers(:battle_master_seven)
    target = hittable_target(armor_class: 1)
    service = maneuver_service(battle_master:, target:)
    service.instance_variable_set(:@initiative_order, [ battle_master, target ])
    gambit = add_gambit(battle_master, position: 1, action_kind: :class_feature,
                                       class_feature: class_features(:fighter_battle_master_maneuver_precision_attack))
    chosen = service.send(:choose_gambit_action, actor: battle_master, gambits: [ gambit ], available: service.send(:available_actions_for, actor: battle_master))
    assert_equal 4, chosen[:uses_remaining]

    Random.srand(1)
    turn = service.send(:gambit_turn, actor: battle_master, chosen_action: chosen, round_number: 1, turn_index: 1)

    assert_equal 1, turn[:results].count { |attack| attack[:rider] }
    assert_equal 3, maneuver_action(service:, actor: battle_master, slug: "precision-attack")[:uses_remaining]
  end

  test "gambits: an 'any' rule takes the first living candidate in initiative order, on every attack" do
    actor = sturdy(fresh_character(:thorin))
    actor.define_singleton_method(:attacks_per_action) { 20 }
    enemies = [ sturdy(fresh_character(:aragorn)), sturdy(fresh_character(:aragorn_copy)) ]
    add_gambit(actor, position: 1)
    service = CombatSimulatorService.new(party_one: [ actor ], party_two: enemies, seed: SEED_WITH_REVERSED_INITIATIVE, max_rounds: 1)

    turn = actor_turns(actor:, result: service.call).first

    order = service.instance_variable_get(:@initiative_order).map(&:id) - [ actor.id ]
    assert_equal enemies.reverse.map(&:id), order, "the seed must put the enemies in initiative order opposite to their party order"
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

      turn = actor_turns(actor:, result: CombatSimulatorService.new(party_one: [ actor ], party_two: enemies, seed:, max_rounds: 1).call).first

      assert_equal "Maneuver: Precision Attack", turn.dig(:action, :maneuver_name)
      assert_equal enemies.second.id, turn[:results].first[:target_id], "seed #{seed}: expected the weakest enemy as target"
    end
  end

  test "gambits: an ally rule includes the actor itself" do
    actor = player_characters(:elora)
    actor.current_hit_points = 4 # below 50% of 10
    mend = Spell.create!(name: "Test Mend", slug: "test-mend", level: 0, school: "evocation", description: "Test-only ally heal.",
                         effect_payload: { kind: "heal", roll: "1d4", target: "ally" })
    PlayerCharacterSpell.create!(player_character: actor, spell: mend)
    ally = sturdy(fresh_character(:aragorn))
    enemy = fresh_character(:merlin)
    add_gambit(actor, position: 1, target: :ally, condition: :hp_below, condition_value: 50, action_kind: :spell, spell: mend)
    service = CombatSimulatorService.new(party_one: [ ally, actor ], party_two: [ enemy ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)
    service.instance_variable_set(:@initiative_order, [ ally, actor, enemy ])

    chosen = service.send(:choose_gambit_action, actor:, gambits: actor.gambits.to_a, available: service.send(:available_actions_for, actor:))

    assert_equal :cast_spell, chosen&.dig(:type)
    assert_equal actor, chosen[:target]
  end

  test "gambits: hp_below fires only strictly below the threshold" do
    actor = fresh_character(:thorin)
    enemy = fresh_character(:aragorn) # max 12
    gambit = add_gambit(actor, position: 1, condition: :hp_below, condition_value: 50)
    service = CombatSimulatorService.new(party_one: [ actor ], party_two: [ enemy ], seed: 1, max_rounds: 1)
    service.send(:initialize_state)
    service.instance_variable_set(:@initiative_order, [ actor, enemy ])

    enemy.current_hit_points = 6 # exactly 50%
    assert_nil service.send(:gambit_target, actor:, gambit:)

    enemy.current_hit_points = 5
    assert_equal enemy, service.send(:gambit_target, actor:, gambit:)

    # 62/125 = 49.6%: below 50% even though it rounds to 50.
    enemy.max_hit_points = 125
    enemy.current_hit_points = 62
    assert_equal enemy, service.send(:gambit_target, actor:, gambit:)
  end

  private

    def fresh_character(fixture_name)
      character = player_characters(fixture_name).dup
      character.id = player_characters(fixture_name).id
      character.current_hit_points = character.max_hit_points
      character
    end

    # Uses the fixture record directly (no #dup): a has_many :through association like
    # #known_maneuvers only queries the database for a persisted owner, and .dup always
    # resets new_record? to true even after manually re-assigning the original id.
    def battle_master_with_known_maneuvers(fixture_name)
      character = player_characters(fixture_name)
      character.current_hit_points = character.max_hit_points
      character
    end

    # Uses the fixture record directly (no #dup), for the same reason as
    # #battle_master_with_known_maneuvers: #spells is a has_many :through
    # association, which only resolves for a persisted owner.
    def spellcaster_with_known_spells(fixture_name)
      character = player_characters(fixture_name)
      character.current_hit_points = character.max_hit_points
      character
    end

    def precision_attack_action(service:, actor:)
      maneuver_action(service:, actor:, slug: "precision-attack")
    end

    def maneuver_action(service:, actor:, slug:)
      service.send(:available_actions_for, actor:).find do |action|
        action[:type] == :class_feature && action[:class_feature].slug == "battle-master-maneuver-#{slug}"
      end
    end

    # A fixture target with a chosen armor class and plenty of HP, so it survives a few hits and the
    # to-hit bonus alone decides whether an attack lands.
    def hittable_target(armor_class:)
      target = player_characters(:aragorn)
      target.combatant.update!(armor_class:, max_hit_points: 1000)
      target.current_hit_points = target.max_hit_points
      target
    end

    def maneuver_service(battle_master:, target:, allies: [])
      service = CombatSimulatorService.new(party_one: [ battle_master, *allies ], party_two: [ target ], seed: 1, max_rounds: 1)
      service.send(:initialize_state)
      service
    end

    def add_gambit(character, position:, target: :enemy, condition: :any, action_kind: :attack, **attributes)
      character.gambits.build(position:, target:, condition:, action_kind:, **attributes)
    end

    # Enough HP that nobody falls over the few rounds a gambit test runs.
    def sturdy(character)
      character.current_hit_points = 1000
      character
    end

    def gambit_service(actor:, enemy: sturdy(fresh_character(:merlin)), max_rounds: 1)
      CombatSimulatorService.new(party_one: [ actor ], party_two: [ enemy ], seed: 5, max_rounds:)
    end

    # The actor's own turn entries (not passives or Action Surge extras).
    def actor_turns(actor:, result:)
      result[:round_log].flat_map { |round| round[:turns] }
        .select { |turn| turn[:actor_id] == actor.id && turn.dig(:action, :type) != :turn_passive && !turn[:extra] }
    end
end
