require "test_helper"

class Combat::FeatureBookTest < ActiveSupport::TestCase
  test "unlocks and action_payload delegate to the character; a feature it lacks has no payload" do
    fighter = player_characters(:aragorn)
    book = Combat::FeatureBook.new(fighter)

    assert_equal fighter.feature_unlocks, book.unlocks
    assert_equal "heal", book.action_payload(class_features(:fighter_second_wind))["kind"]
    assert_nil book.action_payload(class_features(:fighter_battle_master_maneuver_precision_attack)), "not unlocked"
    assert_nil book.action_payload(class_features(:fighter_action_surge)), "not unlocked at level 1"
  end

  test "a maneuver is an action only when the character knows it" do
    player_character_maneuvers(:battle_master_seven_distracting_strike).destroy!
    book = Combat::FeatureBook.new(player_characters(:battle_master_seven))

    assert_equal "damage", book.action_payload(class_features(:fighter_battle_master_maneuver_precision_attack))&.dig("kind")
    assert_nil book.action_payload(class_features(:fighter_battle_master_maneuver_distracting_strike)), "an unlearned maneuver"
  end

  test "a maneuver spends the Combat Superiority pool; any other feature its own uses" do
    book = Combat::FeatureBook.new(player_characters(:battle_master_seven))
    pool = class_features(:fighter_battle_master_combat_superiority)

    assert_equal pool.id, book.resource_feature_id(class_features(:fighter_battle_master_maneuver_precision_attack))
    assert_equal pool.id, book.resource_feature_id(pool)
    assert_equal class_features(:fighter_second_wind).id, book.resource_feature_id(class_features(:fighter_second_wind))
  end

  test "unlock_with returns the unlock in force of the extra_action and the reroll_save, or nil" do
    assert_nil Combat::FeatureBook.new(player_characters(:aragorn)).unlock_with("extra_action")
    assert_nil Combat::FeatureBook.new(player_characters(:aragorn)).unlock_with("reroll_save")
    assert_equal class_feature_unlocks(:action_surge_level_2), Combat::FeatureBook.new(player_characters(:fighter_no_archetype_seven)).unlock_with("extra_action")
    assert_nil Combat::FeatureBook.new(player_characters(:fighter_no_archetype_seven)).unlock_with("reroll_save")
    assert_equal class_feature_unlocks(:indomitable_level_9), Combat::FeatureBook.new(player_characters(:fighter_indomitable_nine)).unlock_with("reroll_save")
  end

  test "War Magic follows a cantrip only; Improved War Magic any spell" do
    cantrip = spells(:fire_bolt)
    leveled = spells(:magic_missile)
    war_magic = Combat::FeatureBook.new(player_characters(:eldritch_knight_seven))
    improved = Combat::FeatureBook.new(player_characters(:eldritch_knight_eighteen))
    none = Combat::FeatureBook.new(player_characters(:aragorn))

    assert_equal [ 1, nil ], [ war_magic.weapon_attacks_after(cantrip), war_magic.weapon_attacks_after(leveled) ]
    assert_equal [ 1, 1 ], [ improved.weapon_attacks_after(cantrip), improved.weapon_attacks_after(leveled) ]
    assert_equal [ nil, nil ], [ none.weapon_attacks_after(cantrip), none.weapon_attacks_after(leveled) ]
  end

  test "a grants_activity is read from its after: only a cantrip with cast_with_action cantrip" do
    unlock = class_feature_unlocks(:eldritch_knight_war_magic_level_7)
    unlock.update!(effect_payload: unlock.effect_payload.merge("count" => 2, "after" => { "cast_with_action" => "any_spell" }))
    book = Combat::FeatureBook.new(player_characters(:eldritch_knight_seven))

    assert_equal [ 2, 2 ], [ book.weapon_attacks_after(spells(:fire_bolt)), book.weapon_attacks_after(spells(:magic_missile)) ]
  end

  test "the disadvantage_on_next_save rider from level 10 of the Eldritch Knight" do
    assert_nil Combat::FeatureBook.new(player_characters(:eldritch_knight_seven)).rider(event: "weapon_hit", applies: "disadvantage_on_next_save")
    assert_equal class_features(:fighter_eldritch_knight_eldritch_strike),
      Combat::FeatureBook.new(player_characters(:eldritch_knight_ten)).rider(event: "weapon_hit", applies: "disadvantage_on_next_save")
  end

  test "initial_uses: the unlock's fixed uses, else its uses_formula; features without either are left out" do
    fighter = player_characters(:fighter_no_archetype_seven)
    uses = Combat::FeatureBook.new(fighter).initial_uses

    assert_equal 1, uses[class_features(:fighter_second_wind).id]
    assert_equal 1, uses[class_features(:fighter_action_surge).id]
    assert_not uses.key?(class_features(:fighter_indomitable).id), "not unlocked at level 7"

    class_feature_unlocks(:second_wind_level_1).update_columns(uses: nil, uses_formula: "actor_level + 1")
    fighter.reload

    assert_same 8, Combat::FeatureBook.new(fighter).initial_uses[class_features(:fighter_second_wind).id], "an Integer: the simulator counts down only Integer uses"
  end

  test "the queries never draw from the RNG" do
    # They run on every turn and attack; a draw would desync every seeded simulation.
    book = Combat::FeatureBook.new(player_characters(:eldritch_knight_ten))
    srand(5)
    book.action_payload(class_features(:fighter_second_wind))
    book.unlock_with("extra_action")
    book.unlock_with("reroll_save")
    book.weapon_attacks_after(spells(:fire_bolt))
    book.rider(event: "weapon_hit", applies: "disadvantage_on_next_save")
    book.resource_feature_id(class_features(:fighter_second_wind))
    book.initial_uses
    drawn = rand
    srand(5)

    assert_equal rand, drawn
  end
end
