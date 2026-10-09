require "test_helper"

class GambitTest < ActiveSupport::TestCase
  test "a valid attack rule saves and reads back with prefixed enums" do
    gambit = build_gambit(target: :enemy, condition: :hp_below, condition_value: 50)

    assert gambit.save, gambit.errors.full_messages.to_sentence
    assert gambit.target_enemy?
    assert gambit.condition_hp_below?
    assert gambit.action_attack?
    assert gambit.enabled?
  end

  test "position must be within 1..6" do
    assert_includes build_gambit(position: 0).tap(&:validate).errors.attribute_names, :position
    assert_includes build_gambit(position: 7).tap(&:validate).errors.attribute_names, :position
    assert build_gambit(position: 6).valid?
  end

  test "the database rejects a position outside 1..6" do
    gambit = build_gambit(position: 1).tap(&:save!)

    assert_raises(ActiveRecord::StatementInvalid) { gambit.update_column(:position, 7) }
  end

  test "an owner holds at most six gambits" do
    owner = player_characters(:aragorn)
    6.times { |index| build_gambit(owner:, position: index + 1).save! }

    seventh = build_gambit(owner: owner.reload, position: 6)
    assert_not seventh.valid?
    assert_includes seventh.errors[:base].join, "at most 6"
  end

  test "editing one of six gambits does not count itself against the limit" do
    owner = player_characters(:aragorn)
    6.times { |index| build_gambit(owner:, position: index + 1).save! }

    assert owner.reload.gambits.first.valid?
  end

  test "the database keeps owner and position unique, deferred to the end of the transaction" do
    build_gambit(position: 1).save!
    build_gambit(position: 1).save! # deferred: no error yet

    assert_raises(ActiveRecord::RecordNotUnique) do
      Gambit.connection.execute("SET CONSTRAINTS gambits_owner_position_unique IMMEDIATE")
    end
  end

  test "the action must match its kind" do
    second_wind = class_features(:fighter_second_wind)
    fire_bolt = spells(:fire_bolt)

    assert_not build_gambit(class_feature: second_wind).valid?
    assert_not build_gambit(action_kind: :class_feature, target: :self).valid?
    assert_not build_gambit(action_kind: :class_feature, target: :self, class_feature: second_wind, spell: fire_bolt).valid?
    assert_not build_gambit(action_kind: :spell).valid?
    assert build_gambit(action_kind: :class_feature, target: :self, class_feature: second_wind).valid?
    assert build_gambit(action_kind: :spell, spell: fire_bolt).valid?
  end

  test "the database rejects an action inconsistent with its kind" do
    gambit = build_gambit.tap(&:save!)

    assert_raises(ActiveRecord::StatementInvalid) { gambit.update_column(:spell_id, spells(:fire_bolt).id) }
  end

  test "the target must fit the action's natural target" do
    second_wind = class_features(:fighter_second_wind)
    precision = class_features(:fighter_battle_master_maneuver_precision_attack)
    healing_word = Spell.new(name: "Healing Word", slug: "healing-word", level: 1, school: "evocation",
                             description: "Heal", effect_payload: { "kind" => "heal", "roll" => "1d4", "target" => "ally" })

    assert_not build_gambit(target: :ally).valid?
    assert_not build_gambit(target: :self).valid?
    assert_not build_gambit(action_kind: :class_feature, target: :enemy, class_feature: second_wind).valid?
    assert_not build_gambit(action_kind: :class_feature, target: :self, class_feature: precision).valid?
    assert build_gambit(action_kind: :class_feature, target: :enemy, class_feature: precision).valid?
    assert build_gambit(action_kind: :spell, target: :ally, spell: healing_word).valid?
    assert build_gambit(action_kind: :spell, target: :self, spell: healing_word).valid?
    assert_not build_gambit(action_kind: :spell, target: :enemy, spell: healing_word).valid?
  end

  test "a feature with no active effect cannot be a gambit action" do
    assert_not build_gambit(action_kind: :class_feature, target: :self, class_feature: class_features(:fighter_action_surge)).valid?
  end

  test "a passive feature cannot be a gambit action, even with a heal or modifier payload" do
    assert_not build_gambit(action_kind: :class_feature, target: :self, class_feature: class_features(:fighter_champion_survivor)).valid?
    assert_not build_gambit(action_kind: :class_feature, target: :self, class_feature: class_features(:fighter_champion_improved_critical)).valid?
  end

  test "a feature whose effect is neither heal nor damage cannot be a gambit action" do
    second_wind = class_features(:fighter_second_wind)
    ClassFeatureUnlock.create!(class_feature: second_wind, level: 10, description: "Test: becomes a buff.",
                               effect_payload: { kind: "modifier", modifier: "armor_class", value: 1, target: "self" })

    assert_not build_gambit(action_kind: :class_feature, target: :self, class_feature: second_wind).valid?
  end

  test "a feature's natural target comes from its highest unlock level that has an effect" do
    second_wind = class_features(:fighter_second_wind)
    ClassFeatureUnlock.create!(class_feature: second_wind, level: 10, description: "Test: becomes an attack.",
                               effect_payload: { kind: "damage", roll: "1d6", target: "enemy" })
    ClassFeatureUnlock.create!(class_feature: second_wind, level: 15, description: "Test: no effect of its own.")

    assert build_gambit(action_kind: :class_feature, target: :enemy, class_feature: second_wind).valid?
    assert_not build_gambit(action_kind: :class_feature, target: :self, class_feature: second_wind).valid?
  end

  test "condition_value is required within 1..99 for hp_below and blank otherwise" do
    assert_not build_gambit(condition: :hp_below).valid?
    assert_not build_gambit(condition: :hp_below, condition_value: 0).valid?
    assert_not build_gambit(condition: :hp_below, condition_value: 100).valid?
    assert build_gambit(condition: :hp_below, condition_value: 99).valid?
    assert_not build_gambit(condition: :lowest_hp, condition_value: 50).valid?
    assert build_gambit(condition: :lowest_hp).valid?
  end

  test "label reads target, condition and action in Portuguese" do
    assert_equal "Inimigo: HP < 50% → Ataque", build_gambit(condition: :hp_below, condition_value: 50).label
    assert_equal "Self: qualquer → Second Wind",
                 build_gambit(action_kind: :class_feature, target: :self, class_feature: class_features(:fighter_second_wind)).label
    assert_equal "Inimigo: menor HP → Maneuver: Precision Attack",
                 build_gambit(condition: :lowest_hp, action_kind: :class_feature,
                              class_feature: class_features(:fighter_battle_master_maneuver_precision_attack)).label
    assert_equal "Inimigo: qualquer → Fire Bolt", build_gambit(action_kind: :spell, spell: spells(:fire_bolt)).label
  end

  test "a character lists its gambits by position and destroys them with it" do
    owner = player_characters(:aragorn)
    build_gambit(owner:, position: 2).save!
    build_gambit(owner:, position: 1, condition: :lowest_hp).save!

    assert_equal [ 1, 2 ], owner.reload.gambits.map(&:position)
    assert_includes owner.gambits.to_sql, 'ORDER BY "gambits"."position" ASC'
    assert_difference("Gambit.count", -2) { owner.destroy }
  end

  private

    def build_gambit(owner: player_characters(:aragorn), position: 1, target: :enemy, condition: :any, action_kind: :attack, **attributes)
      Gambit.new(owner:, position:, target:, condition:, action_kind:, **attributes)
    end
end
