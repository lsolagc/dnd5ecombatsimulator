require "test_helper"
require "minitest/mock"

class Combat::TurnExecutorTest < ActiveSupport::TestCase
  ATTACK = Combat::ActionOption.new(type: :attack)

  setup { @hit_points = {} }

  test "weapon and spell attacks log the same attack_roll, against the target's effective AC" do
    fire_bolt = spells(:fire_bolt)
    fire_bolt.update!(effect_payload: fire_bolt.effect_payload.merge("attack" => "spell"))
    caster = spellcaster_with_known_spells(:eldritch_knight_seven)
    defender = sturdy(player_characters(:fighter_defender))
    # No seed declares an AC passive (the sheet's AC is final); one declared here, so the effective AC differs.
    class_feature_unlocks(:fighting_style_defense_level_1)
      .update!(effect_payload: { kind: "modifier", trigger: "always", modifier: "armor_class", value: 1 })
    encounter, executor = fight(party_one: [ caster ], party_two: [ defender ])
    actor = participant_of(encounter, caster)
    cast = actor.action_options.find { |action| action.spell&.slug == "fire-bolt" }

    spell = executor.run(actor:, option: cast, round: 1, turn: 1).results.sole
    weapon = executor.run(actor:, option: ATTACK, round: 1, turn: 1).results.sole

    [ weapon, spell ].each do |entry|
      assert_equal %i[ natural total armor_class hit crit ], entry[:attack_roll].keys
      assert_equal defender.combatant.armor_class + 1, entry.dig(:attack_roll, :armor_class)
    end
    assert_equal %i[ kind target_id target_name advantage riders amount hp_before hp_after roll_outcome attack_roll ], weapon.keys
    assert_equal weapon[:hp_before] - weapon[:hp_after], weapon.dig(:attack_roll, :hit) ? weapon[:amount] : 0
  end

  test "a maneuver rides on a weapon attack: its die is added on a hit, spending one superiority die, and nothing on a miss" do
    battle_master = battle_master_with_known_maneuvers(:battle_master_seven)
    target = hittable_target(armor_class: 1)
    encounter, executor = fight(party_one: [ battle_master ], party_two: [ target ])
    fighter = participant_of(encounter, battle_master)

    action = maneuver_action(fighter, "precision-attack")
    assert action, "expected Precision Attack to be available to a Battle Master who knows it"
    assert_equal 4, action.uses_remaining

    Random.srand(1)
    turn = executor.run(actor: fighter, option: action, round: 1, turn: 1)

    assert_equal :attack, turn.action[:type]
    precision = { feature_slug: "battle-master-maneuver-precision-attack", feature_name: "Maneuver: Precision Attack" }
    assert_equal [ precision ], turn.action[:riders]
    attack = turn.results.first
    assert attack.dig(:attack_roll, :hit)
    rider = attack[:riders].sole
    assert_equal precision, rider.slice(:feature_slug, :feature_name)
    assert_equal :damage, rider[:kind]
    assert_includes 1..8, rider[:amount]
    assert_not rider.key?(:statuses), "Precision Attack applies no status"
    assert_equal 3, maneuver_action(fighter, "precision-attack").uses_remaining

    target.combatant.update!(armor_class: 100)
    Random.srand(1)
    miss_turn = executor.run(actor: fighter, option: action, round: 1, turn: 1)
    miss = miss_turn.results.first

    assert_not miss.dig(:attack_roll, :hit)
    assert_equal [], miss[:riders], "a rider applies only on a hit"
    assert_equal [ precision ], miss_turn.action[:riders], "the chosen rider is logged even when nothing hit"
    assert_equal 3, maneuver_action(fighter, "precision-attack").uses_remaining, "a miss must not spend a die"

    spend_all_uses(fighter, class_features(:fighter_battle_master_combat_superiority))

    assert_nil maneuver_action(fighter, "precision-attack")
  end

  test "Distracting Strike marks the target only when the attack hits, and the mark is spent by the first other attacker" do
    battle_master = battle_master_with_known_maneuvers(:battle_master_seven)
    ally = fresh_character(:aragorn_copy)
    target = hittable_target(armor_class: 100)
    encounter, executor = fight(party_one: [ battle_master, ally ], party_two: [ target ])
    marks = -> { participant_of(encounter, target).statuses.map { |status| [ status.kind, status.source.id, status.ends ] } }
    fighter = participant_of(encounter, battle_master)
    strike = maneuver_action(fighter, "distracting-strike")
    strike_now = -> { executor.run(actor: fighter, option: strike, round: 1, turn: 1) }
    attack_now = ->(actor) { executor.run(actor: participant_of(encounter, actor), option: ATTACK, round: 1, turn: 1).results.first }

    Random.srand(1) # AC 100: a miss
    assert_not strike_now.call.results.first.dig(:attack_roll, :hit)
    assert_empty marks.call, "no hit, no mark"

    target.combatant.update!(armor_class: 1)
    Random.srand(1)
    hit = strike_now.call.results.first
    assert hit.dig(:attack_roll, :hit)
    assert_equal [ "next_attack_advantage" ], hit[:riders].sole[:statuses], "the log keeps only the kinds"
    assert_equal [ [ "next_attack_advantage", battle_master.combatant.id, "source_turn_start" ] ], marks.call

    assert_not attack_now.(battle_master)[:advantage], "the mark never helps the one who set it"
    assert_equal [ [ "next_attack_advantage", battle_master.combatant.id, "source_turn_start" ] ], marks.call

    assert attack_now.(ally)[:advantage], "the next attack by anyone else has advantage"
    assert_empty marks.call
    assert_not attack_now.(ally)[:advantage], "the mark is consumed by that one attack"
  end

  test "Distracting Strike again by the same Battle Master renews its mark instead of stacking it" do
    battle_master = battle_master_with_known_maneuvers(:battle_master_seven)
    ally = fresh_character(:aragorn_copy)
    target = hittable_target(armor_class: 1)
    encounter, executor = fight(party_one: [ battle_master, ally ], party_two: [ target ])
    fighter = participant_of(encounter, battle_master)
    strike = maneuver_action(fighter, "distracting-strike")
    attack_now = -> { executor.run(actor: participant_of(encounter, ally), option: ATTACK, round: 1, turn: 1).results.sole }

    2.times do |turn|
      Random.srand(1)
      assert executor.run(actor: fighter, option: strike, round: 1, turn:).results.first.dig(:attack_roll, :hit)
    end

    assert_equal [ battle_master.combatant.id ], participant_of(encounter, target).statuses.map { |status| status.source.id }
    assert attack_now.call[:advantage]
    assert_not attack_now.call[:advantage], "two hits from the same source leave one mark: one advantage"
  end

  test "marks from two sources give one attack advantage once and are all used up by it; the attacker's own mark stays" do
    battle_master = battle_master_with_known_maneuvers(:battle_master_seven)
    other_marker, attacker = fresh_character(:aragorn_copy), fresh_character(:merlin)
    target = hittable_target(armor_class: 1)
    encounter, executor = fight(party_one: [ battle_master, other_marker, attacker ], party_two: [ target ])
    marked = participant_of(encounter, target)
    [ battle_master, other_marker, attacker ].each do |source|
      marked.add_status(Combat::Status.new(kind: "next_attack_advantage", source: participant_of(encounter, source), ends: "source_turn_start"))
    end
    attack_now = -> { executor.run(actor: participant_of(encounter, attacker), option: ATTACK, round: 1, turn: 1).results.sole }

    # Advantage does not stack (5e): two marks that apply still make one attack with advantage, not two.
    assert attack_now.call[:advantage]
    assert_equal [ attacker.combatant.id ], marked.statuses.map { |status| status.source.id }, "both marks that applied are gone, the attacker's own is left"
    assert_not attack_now.call[:advantage], "the attacker's own mark never helps it"
  end

  test "Action Surge grants an extra action on the same turn and respects the uses limit" do
    actor = fresh_character(:fighter_no_archetype_seven)
    encounter, executor = fight(party_one: [ actor ], party_two: [ fresh_character(:aragorn_copy) ])
    fighter = participant_of(encounter, actor)

    # Second Wind is otherwise available at this level; disable it so the extra action
    # deterministically resolves to a plain attack (only remaining option).
    spend_all_uses(fighter, class_features(:fighter_second_wind))

    action_surge_id = class_features(:fighter_action_surge).id
    assert_equal 1, fighter.uses_left(action_surge_id)

    Random.srand(1)
    extra_turn = executor.action_surge_turn(actor: fighter, round: 1, turn: 1)

    assert extra_turn, "expected Action Surge to grant an extra action"
    assert_equal true, extra_turn.extra
    assert_equal :attack, extra_turn.action[:type]
    assert_equal 0, fighter.uses_left(action_surge_id)

    assert_nil executor.action_surge_turn(actor: fighter, round: 1, turn: 2)
  end

  test "Indomitable rerolls a failed saving throw against the fighter and consumes a use, whatever its name" do
    class_features(:fighter_indomitable).update_columns(name: "Indomável") # found by its reroll_save kind
    fighter = player_characters(:fighter_indomitable_nine) # constitution: 12 (mod +1)
    attacker = player_characters(:barbarian_test_striker)

    encounter, executor = fight(party_one: [ attacker ], party_two: [ fighter ])
    attacker, fighter = participant_of(encounter, attacker), participant_of(encounter, fighter)

    chosen_action = attacker.action_options.find do |action|
      action.type == :class_feature && action.class_feature.slug == "test-save-strike"
    end
    assert chosen_action, "expected the test save-strike fixture to be available to the attacker"

    indomitable_id = class_features(:fighter_indomitable).id
    assert_equal 1, fighter.uses_left(indomitable_id)

    Random.srand(46) # 1d6 roll = 6; 1st constitution save total 7 (fails dc 8); reroll total 10 (succeeds)
    turn = executor.run(actor: attacker, option: chosen_action, round: 1, turn: 1)

    damage_result = turn.results.first
    assert_equal :damage, damage_result[:kind]
    assert_equal 3, damage_result[:amount] # half of 6, since the reroll succeeded

    assert_equal 0, fighter.uses_left(indomitable_id)
  end

  test "choose_at_random picks the physical branch when the coin flip favors it" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven)
    encounter, executor = fight(party_one: [ caster ], party_two: [ fresh_character(:aragorn) ], seed: 1)
    caster = participant_of(encounter, caster)

    chosen = executor.choose_at_random(actor: caster, options: caster.action_options)

    assert_equal :attack, chosen.type
  end

  test "choose_at_random picks the spell branch when the coin flip favors it" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven)
    encounter, executor = fight(party_one: [ caster ], party_two: [ fresh_character(:aragorn) ], seed: 3)
    caster = participant_of(encounter, caster)

    chosen = executor.choose_at_random(actor: caster, options: caster.action_options)

    assert_equal :cast_spell, chosen.type
    assert_equal "magic-missile", chosen.spell.slug
  end

  test "choose_at_random does not consume extra randomness for a non-spellcasting actor" do
    # Comparing only the chosen action is not a reliable regression guard: for some
    # seeds/list sizes, an extra rng draw before the real sample still lands on the
    # same element by coincidence. Compare the RNG's internal state instead, which only
    # matches if the exact same sequence of draws happened.
    actor = fresh_character(:aragorn)
    plain_rng, heuristic_rng = Random.new(5), Random.new(5)
    encounter = build_encounter(party_one: [ actor ], party_two: [ fresh_character(:aragorn_copy) ], hit_points: @hit_points)
    executor = build_turn_executor(encounter, rng: heuristic_rng)
    actor = participant_of(encounter, actor)
    options = actor.action_options

    options.sample(random: plain_rng)
    executor.choose_at_random(actor:, options:)

    assert_equal Marshal.dump(plain_rng), Marshal.dump(heuristic_rng),
      "choose_at_random must consume rng identically to a single options.sample(random: rng) call"
  end

  test "War Magic grants a bonus weapon attack when the turn's normal action casts a cantrip" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven)
    encounter, executor = fight(party_one: [ caster ], party_two: [ fresh_character(:aragorn) ])
    caster = participant_of(encounter, caster)

    chosen_action = caster.action_options.find do |action|
      action.spell&.slug == "fire-bolt"
    end
    assert chosen_action, "expected fire-bolt (a cantrip) to be an available action"

    Random.srand(1)
    bonus_turn = executor.war_magic_turn(actor: caster, option: chosen_action, round: 1, turn: 1)

    assert bonus_turn, "expected War Magic to grant a bonus weapon attack"
    assert_equal true, bonus_turn.bonus
    assert_equal :attack, bonus_turn.action[:type]
  end

  test "War Magic does not grant a bonus attack for a non-cantrip spell before Improved War Magic" do
    caster = spellcaster_with_known_spells(:eldritch_knight_seven)
    chosen_action = Combat::ActionOption.new(type: :cast_spell, spell: spells(:magic_missile))
    encounter, executor = fight(party_one: [ caster ], party_two: [ fresh_character(:aragorn) ])

    assert_nil executor.war_magic_turn(actor: participant_of(encounter, caster), option: chosen_action, round: 1, turn: 1)
  end

  test "Improved War Magic grants a bonus weapon attack even for a non-cantrip spell" do
    caster = spellcaster_with_known_spells(:eldritch_knight_eighteen)
    encounter, executor = fight(party_one: [ caster ], party_two: [ fresh_character(:aragorn) ])
    caster = participant_of(encounter, caster)

    chosen_action = caster.action_options.find do |action|
      action.spell&.slug == "magic-missile"
    end
    assert chosen_action, "expected magic-missile to be an available action"

    Random.srand(1)
    bonus_turn = executor.war_magic_turn(actor: caster, option: chosen_action, round: 1, turn: 1)

    assert bonus_turn, "expected Improved War Magic to grant a bonus weapon attack for a non-cantrip spell"
    assert_equal true, bonus_turn.bonus
    assert_equal :attack, bonus_turn.action[:type]
  end

  test "a successful weapon attack from an Eldritch Knight with Eldritch Strike marks the target as pending" do
    caster = spellcaster_with_known_spells(:eldritch_knight_ten)
    target = fresh_character(:aragorn)
    encounter, executor = fight(party_one: [ caster ], party_two: [ target ])

    Random.srand(1)
    turn = executor.run(actor: participant_of(encounter, caster), option: ATTACK, round: 1, turn: 1)

    assert_equal true, turn.results.first.dig(:attack_roll, :hit), "expected the attack to hit (attack_bonus is set high for determinism)"
    assert_equal [ [ "disadvantage_on_next_save", caster.combatant.id, nil ] ],
      participant_of(encounter, target).statuses.map { |status| [ status.kind, status.source.id, status.ends ] }, "no end of its own: only a save uses it up"
  end

  test "two Eldritch Knights hitting the same target each keep their own disadvantage" do
    first, second = spellcaster_with_known_spells(:eldritch_knight_ten), spellcaster_with_known_spells(:eldritch_knight_eighteen)
    target = hittable_target(armor_class: 1)
    encounter, executor = fight(party_one: [ first, second ], party_two: [ target ])
    first, second, target = [ first, second, target ].map { |character| participant_of(encounter, character) }

    Dice.stub(:hit?, true) { [ first, second ].each { |knight| executor.run(actor: knight, option: ATTACK, round: 1, turn: 1) } }
    assert_equal [ first, second ], target.statuses.map(&:source), "the second attacker's mark does not erase the first's"

    save_spell = first.action_options.find { |action| action.spell&.slug == "test-save-spell" }
    executor.run(actor: first, option: save_spell, round: 1, turn: 2)
    assert_equal [ second ], target.statuses.map(&:source), "a spell from the first uses up only the first's"
  end

  test "Eldritch Strike is logged as a rider on the attack that hits, not on a miss" do
    caster = spellcaster_with_known_spells(:eldritch_knight_ten)
    target = hittable_target(armor_class: 1)
    encounter, executor = fight(party_one: [ caster ], party_two: [ target ])

    Random.srand(1)
    hit = executor.run(actor: participant_of(encounter, caster), option: ATTACK, round: 1, turn: 1)

    assert hit.results.sole.dig(:attack_roll, :hit)
    assert_equal [ { feature_slug: "eldritch-knight-eldritch-strike", feature_name: "Eldritch Strike", statuses: [ "disadvantage_on_next_save" ] } ],
      hit.results.sole[:riders]
    assert_equal({ type: :attack }, hit.action, "Eldritch Strike rides by itself: no rider is chosen")

    target.combatant.update!(armor_class: 100)
    Random.srand(1)
    miss = executor.run(actor: participant_of(encounter, caster), option: ATTACK, round: 1, turn: 2)

    assert_not miss.results.sole.dig(:attack_roll, :hit)
    assert_equal [], miss.results.sole[:riders]
  end

  test "Eldritch Strike imposes disadvantage on the target's next save against the same caster's spell, then stops" do
    caster = spellcaster_with_known_spells(:eldritch_knight_ten)
    target = fresh_character(:aragorn) # dexterity 12 (mod +1)
    encounter, executor = fight(party_one: [ caster ], party_two: [ target ])
    caster = participant_of(encounter, caster)
    participant_of(encounter, target).add_status(Combat::Status.new(kind: "disadvantage_on_next_save", source: caster, ends: nil))

    chosen_action = caster.action_options.find do |action|
      action.spell&.slug == "test-save-spell"
    end
    assert chosen_action, "expected test-save-spell to be an available action"

    # seed 4: 1d6 damage roll = 3; disadvantage keeps the worse of two d20 saves
    # (+1 dexterity modifier) = total 7, failing DC 8 -> full damage (3).
    Random.srand(4)
    first_turn = executor.run(actor: caster, option: chosen_action, round: 1, turn: 1)
    assert_equal 3, first_turn.results.first[:amount], "expected disadvantage to cause the save to fail (full damage)"

    assert_empty participant_of(encounter, target).statuses, "expected the Eldritch Strike mark to be consumed by the first save"

    # Same seed, no pending mark this time: only one d20 is rolled (total 16), the save
    # succeeds against DC 8, halving the damage (3 / 2 = 1).
    Random.srand(4)
    second_turn = executor.run(actor: caster, option: chosen_action, round: 1, turn: 2)
    assert_equal 1, second_turn.results.first[:amount], "expected the second save, without disadvantage, to succeed and halve damage"
  end

  test "a spell without a save leaves the Eldritch Strike mark for the caster's next save spell" do
    caster = spellcaster_with_known_spells(:eldritch_knight_ten)
    target = fresh_character(:aragorn) # dexterity 12 (mod +1)
    encounter, executor = fight(party_one: [ caster ], party_two: [ target ])
    caster = participant_of(encounter, caster)
    marked = participant_of(encounter, target)
    marked.add_status(Combat::Status.new(kind: "disadvantage_on_next_save", source: caster, ends: nil))
    aimed = ->(option) { option.with(target: marked, gambit: Gambit.new(position: 1, target: :enemy, condition: :any, action_kind: :spell)) }

    fire_bolt = Combat::ActionOption.new(type: :cast_spell, spell: spells(:fire_bolt), payload: spells(:fire_bolt).effect_payload.deep_stringify_keys)
    executor.run(actor: caster, option: aimed.(fire_bolt), round: 1, turn: 1)
    assert_equal [ caster ], marked.statuses.map(&:source), "a spell that calls for no save must not use the mark up"

    save_spell = caster.action_options.find { |action| action.spell&.slug == "test-save-spell" }
    Random.srand(4) # same roll math as the sibling test: with disadvantage the save fails -> full damage (3)
    turn = executor.run(actor: caster, option: aimed.(save_spell), round: 1, turn: 2)
    assert_equal 3, turn.results.first[:amount]
    assert_empty marked.statuses
  end

  test "Eldritch Strike's disadvantage does not leak to a different attacker or a different target" do
    marked_target = fresh_character(:aragorn) # dexterity 12 (mod +1)

    # A different attacker must not benefit from someone else's mark on the target.
    other_caster = spellcaster_with_known_spells(:eldritch_knight_eighteen)
    attacker_leak, attacker_leak_executor = fight(party_one: [ other_caster ], party_two: [ marked_target ])
    other_caster = participant_of(attacker_leak, other_caster)
    someone_else = Combat::Participant.new(player_characters(:eldritch_knight_ten))
    participant_of(attacker_leak, marked_target).add_status(Combat::Status.new(kind: "disadvantage_on_next_save", source: someone_else, ends: nil))

    other_action = other_caster.action_options.find do |action|
      action.spell&.slug == "test-save-spell"
    end
    assert other_action, "expected test-save-spell to be available to the other caster"

    # Same seed/roll math as the sibling test's "no disadvantage" branch: a single d20
    # save succeeds, halving damage -> a different attacker never gets the disadvantage.
    Random.srand(4)
    leaked_turn = attacker_leak_executor.run(actor: other_caster, option: other_action, round: 1, turn: 1)
    assert_equal 1, leaked_turn.results.first[:amount], "a different attacker must not receive the marked target's disadvantage"

    # The same attacker must not get disadvantage against a target they haven't marked.
    marker = spellcaster_with_known_spells(:eldritch_knight_ten)
    unmarked_target = fresh_character(:aragorn_copy)
    target_leak, target_leak_executor = fight(party_one: [ marker ], party_two: [ unmarked_target, marked_target ])
    marker = participant_of(target_leak, marker)
    other_target = participant_of(target_leak, marked_target) # in the same fight, marked by the caster
    other_target.add_status(Combat::Status.new(kind: "disadvantage_on_next_save", source: marker, ends: nil))

    marker_action = marker.action_options.find do |action|
      action.spell&.slug == "test-save-spell"
    end
    assert marker_action, "expected test-save-spell to be available to the marking attacker"
    aimed = marker_action.with(target: participant_of(target_leak, unmarked_target), gambit: Gambit.new(position: 1, target: :enemy, condition: :any, action_kind: :spell)) # aimed, like a gambit pick

    Random.srand(4)
    unmarked_turn = target_leak_executor.run(actor: marker, option: aimed, round: 1, turn: 1)
    assert_equal 1, unmarked_turn.results.first[:amount], "the same attacker casting against an unmarked target must not get disadvantage"
    assert_equal [ marker ], other_target.statuses.map(&:source), "the mark on the other target must stay"
  end

  test "a feature's target kind restricts who it may pick: enemy never self or allies, ally never enemies" do
    actor = fresh_character(:aragorn)
    ally = fresh_character(:aragorn_copy)
    enemies = [ fresh_character(:merlin), fresh_character(:elora) ]
    encounter, executor = fight(party_one: [ actor, ally ], party_two: enemies)
    actor, ally = participant_of(encounter, actor), participant_of(encounter, ally)
    enemies = enemies.map { |enemy| participant_of(encounter, enemy) }

    picks = ->(target) { 50.times.map { executor.random_target(actor:, payload: { "target" => target }) }.uniq }

    assert_empty picks.("enemy") - enemies
    assert_empty picks.("ally") - [ actor, ally ]
    assert_equal [ actor ], picks.("self")
    assert_raises(ArgumentError) { picks.("target") }
  end

  test "an enemy-targeted feature has no target once every enemy is down" do
    actor = fresh_character(:aragorn)
    downed = fresh_character(:merlin)
    @hit_points[downed.combatant.id] = 0
    encounter, executor = fight(party_one: [ actor ], party_two: [ downed ])

    assert_nil executor.random_target(actor: participant_of(encounter, actor), payload: { "target" => "enemy" })
  end

  test "gambits: a feature fired by a gambit spends exactly one use" do
    second_wind = class_features(:fighter_second_wind)
    class_feature_unlocks(:second_wind_level_1).update!(uses: 3)
    actor = sturdy(fresh_character(:aragorn))
    add_gambit(actor, position: 1, target: :self, action_kind: :class_feature, class_feature: second_wind)
    encounter, executor = fight(party_one: [ actor ], party_two: [ sturdy(fresh_character(:merlin)) ])
    fighter = participant_of(encounter, actor)
    assert_equal 3, fighter.uses_left(second_wind.id)

    turns = executor.take_turn(fighter, round: 1, turn: 1)

    assert_equal 1, turns.count { |turn| turn.actor_id == actor.combatant.id && turn.action[:feature_slug] == "second-wind" }
    assert_equal 2, fighter.uses_left(second_wind.id)
  end

  test "gambits: each extra attack re-runs the rule, then falls back to the first living enemy in initiative order" do
    actor = fresh_character(:thorin)
    actor.define_singleton_method(:attacks_per_action) { 3 }
    enemies = %i[aragorn aragorn_copy elora fighter_archer fighter_defender].map { |name| fresh_character(name) }
    a, b, c, d, e = enemies
    @hit_points[a.combatant.id] = @hit_points[d.combatant.id] = 5 # below 50%: the rule's only candidates
    gambit = add_gambit(actor, position: 1, condition: :hp_below, condition_value: 50)
    encounter, executor = fight(party_one: [ actor ], party_two: enemies, initiative_order: [ e, actor, c, a, d, b ])
    enemies.each { |enemy| participant_of(encounter, enemy).define_singleton_method(:take_damage) { |**| @current_hit_points = 0 } }

    turn = Dice.stub(:hit?, true) do # every attack hits and kills
      executor.run(actor: participant_of(encounter, actor), option: ATTACK.with(gambit:), round: 1, turn: 1)
    end

    # a and d by the rule (in initiative order), then e: the first living enemy in initiative order
    # (not b, the first in party order).
    assert_equal [ a.combatant.id, d.combatant.id, e.combatant.id ], turn.results.map { |attack| attack[:target_id] }
  end

  test "gambits: a maneuver fired by a gambit spends exactly one superiority die on a hit" do
    battle_master = battle_master_with_known_maneuvers(:battle_master_seven)
    target = hittable_target(armor_class: 1)
    encounter, executor = fight(party_one: [ battle_master ], party_two: [ target ])
    fighter = participant_of(encounter, battle_master)
    add_gambit(battle_master, position: 1, action_kind: :class_feature,
                              class_feature: class_features(:fighter_battle_master_maneuver_precision_attack))
    chosen = Combat::GambitPolicy.new(encounter:).choose(actor: fighter, options: fighter.action_options)
    assert_equal 4, chosen.uses_remaining

    Random.srand(1)
    turn = executor.run(actor: fighter, option: chosen, round: 1, turn: 1)

    assert_equal 1, turn.results.count { |attack| attack[:riders].any? }
    assert_equal 3, maneuver_action(fighter, "precision-attack").uses_remaining
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

    def maneuver_action(participant, slug)
      participant.action_options.find do |action|
        action.type == :class_feature && action.class_feature.slug == "battle-master-maneuver-#{slug}"
      end
    end

    # A fixture target with a chosen armor class and plenty of HP, so it survives a few hits and the
    # to-hit bonus alone decides whether an attack lands.
    def hittable_target(armor_class:)
      target = player_characters(:aragorn)
      target.combatant.update!(armor_class:, max_hit_points: 1000)
      target
    end

    def add_gambit(character, position:, target: :enemy, condition: :any, action_kind: :attack, **attributes)
      character.gambits.build(position:, target:, condition:, action_kind:, **attributes)
    end

    # Starts with enough HP that nobody falls over the few rounds a gambit test runs.
    def sturdy(character)
      @hit_points[character.combatant.id] = 1000
      character
    end

    def spend_all_uses(participant, feature)
      participant.uses_left(feature.id).times { participant.spend_use!(feature.id) }
    end

    # The encounter, with the starting HP the test set, and its turn executor with a simulator's RNG for the seed.
    def fight(party_one:, party_two:, seed: 1, initiative_order: nil)
      encounter = build_encounter(party_one:, party_two:, hit_points: @hit_points, initiative_order:)
      [ encounter, build_turn_executor(encounter, rng: Random.new(seed)) ]
    end
end
