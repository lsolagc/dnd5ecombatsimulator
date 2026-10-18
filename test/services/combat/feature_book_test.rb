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

  test "action_surge and indomitable return the unlock in force, or nil" do
    assert_nil Combat::FeatureBook.new(player_characters(:aragorn)).action_surge
    assert_nil Combat::FeatureBook.new(player_characters(:aragorn)).indomitable
    assert_equal class_feature_unlocks(:action_surge_level_2), Combat::FeatureBook.new(player_characters(:fighter_no_archetype_seven)).action_surge
    assert_nil Combat::FeatureBook.new(player_characters(:fighter_no_archetype_seven)).indomitable
    assert_equal class_feature_unlocks(:indomitable_level_9), Combat::FeatureBook.new(player_characters(:fighter_indomitable_nine)).indomitable
  end

  test "War Magic follows a cantrip only; Improved War Magic any spell" do
    cantrip = spells(:fire_bolt)
    leveled = spells(:magic_missile)
    war_magic = Combat::FeatureBook.new(player_characters(:eldritch_knight_seven))
    improved = Combat::FeatureBook.new(player_characters(:eldritch_knight_eighteen))
    none = Combat::FeatureBook.new(player_characters(:aragorn))

    assert_equal [ true, false ], [ war_magic.war_magic_for?(cantrip), war_magic.war_magic_for?(leveled) ]
    assert_equal [ true, true ], [ improved.war_magic_for?(cantrip), improved.war_magic_for?(leveled) ]
    assert_equal [ false, false ], [ none.war_magic_for?(cantrip), none.war_magic_for?(leveled) ]
  end

  test "eldritch_strike? from level 10 of the Eldritch Knight" do
    assert_not Combat::FeatureBook.new(player_characters(:eldritch_knight_seven)).eldritch_strike?
    assert Combat::FeatureBook.new(player_characters(:eldritch_knight_ten)).eldritch_strike?
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
    book.action_surge
    book.indomitable
    book.war_magic_for?(spells(:fire_bolt))
    book.eldritch_strike?
    book.resource_feature_id(class_features(:fighter_second_wind))
    book.initial_uses
    drawn = rand
    srand(5)

    assert_equal rand, drawn
  end
end
