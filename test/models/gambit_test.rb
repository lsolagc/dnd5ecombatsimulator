require "test_helper"

class GambitTest < ActiveSupport::TestCase
  test "log_section lists every rule, enabled or not, in priority order, and the mode they put the combatant in" do
    second_wind = Gambit.new(position: 1, target: :self, condition: :any, action_kind: :class_feature, class_feature: class_features(:fighter_second_wind))
    disabled = Gambit.new(position: 2, target: :enemy, condition: :any, action_kind: :attack, enabled: false)

    assert_equal({ mode: "gambits", rules: [
      { position: 1, enabled: true, target: "Self", condition: "qualquer", action: "Second Wind", rule: "Self: qualquer → Second Wind" },
      { position: 2, enabled: false, target: "Inimigo", condition: "qualquer", action: "Ataque", rule: "Inimigo: qualquer → Ataque" }
    ] }, Gambit.log_section(snapshots: [ disabled.snapshot, second_wind.snapshot ]))
    assert_equal "aleatório", Gambit.log_section(snapshots: [ disabled.snapshot ])[:mode], "only disabled rules"
    assert_equal({ mode: "aleatório", rules: [] }, Gambit.log_section(snapshots: []))
  end

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

  test "the database rejects a position below 1 and leaves the ceiling to Gambit::MAX_PER_OWNER" do
    gambit = build_gambit(position: 1).tap(&:save!)

    gambit.update_column(:position, 7)
    assert_equal 7, gambit.reload.position, "the database has no ceiling"
    assert_raises(ActiveRecord::StatementInvalid) { gambit.update_column(:position, 0) }
  end

  test "an owner holds at most six gambits" do
    owner = player_characters(:aragorn)
    6.times { |index| build_gambit(owner:, position: index + 1).save! }

    seventh = build_gambit(owner: owner.reload, position: 6)
    assert_not seventh.valid?
    assert_includes seventh.errors[:base].join, "No máximo 6"
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
    battle_master = player_characters(:battle_master_seven)
    assert_not build_gambit(owner: battle_master, action_kind: :class_feature, target: :self, class_feature: precision).valid?
    assert build_gambit(owner: battle_master, action_kind: :class_feature, target: :enemy, class_feature: precision).valid?
    assert build_gambit(action_kind: :spell, target: :ally, spell: healing_word).valid?
    assert build_gambit(action_kind: :spell, target: :self, spell: healing_word).valid?
    assert_not build_gambit(action_kind: :spell, target: :enemy, spell: healing_word).valid?
  end

  test "a feature with no active effect cannot be a gambit action" do
    assert_not build_gambit(action_kind: :class_feature, target: :self, class_feature: class_features(:fighter_indomitable)).valid?
  end

  test "Action Surge is a gambit action targeting Self, though it has no effect payload" do
    action_surge = class_features(:fighter_action_surge)

    assert build_gambit(action_kind: :class_feature, target: :self, class_feature: action_surge).valid?
    assert_not build_gambit(action_kind: :class_feature, target: :enemy, class_feature: action_surge).valid?
    assert_not build_gambit(action_kind: :class_feature, target: :ally, class_feature: action_surge).valid?
  end

  test "a passive feature cannot be a gambit action, even with a heal or modifier payload" do
    assert_not build_gambit(action_kind: :class_feature, target: :self, class_feature: class_features(:fighter_champion_survivor)).valid?
    assert_not build_gambit(action_kind: :class_feature, target: :self, class_feature: class_features(:fighter_champion_improved_critical)).valid?
  end

  test "a feature whose effect is neither heal nor damage cannot be a gambit action" do
    second_wind = class_features(:fighter_second_wind)
    ClassFeatureUnlock.create!(class_feature: second_wind, level: 10, description: "Test: becomes a buff.",
                               effect_payload: { kind: "modifier", modifier: "armor_class", value: 1, target: "self" })

    assert_not build_gambit(owner: player_characters(:champion_eighteen), action_kind: :class_feature, target: :self, class_feature: second_wind).valid?
  end

  test "a character's rule reads the feature's effect at the character's level, a preset's at its highest unlock with one" do
    second_wind = class_features(:fighter_second_wind)
    ClassFeatureUnlock.create!(class_feature: second_wind, level: 10, description: "Test: becomes an attack.",
                               effect_payload: { kind: "damage", roll: "1d6", target: "enemy" })
    ClassFeatureUnlock.create!(class_feature: second_wind, level: 15, description: "Test: no effect of its own.")
    rule = ->(owner, target) { build_gambit(owner:, action_kind: :class_feature, target:, class_feature: second_wind) }

    [ GambitPreset.new(name: "Sem nível"), player_characters(:champion_eighteen) ].each do |owner|
      assert rule.(owner, :enemy).valid?, "#{owner.name}: the level 10 effect, inherited past level 15"
      assert_not rule.(owner, :self).valid?, owner.name
    end
    level_one = player_characters(:aragorn)
    assert rule.(level_one, :self).valid?, "level 1 still heals itself"
    assert_not rule.(level_one, :enemy).valid?
  end

  test "condition_value is required within 1..99 for hp_below and blank otherwise" do
    assert_not build_gambit(condition: :hp_below).valid?
    assert_not build_gambit(condition: :hp_below, condition_value: 0).valid?
    assert_not build_gambit(condition: :hp_below, condition_value: 100).valid?
    assert build_gambit(condition: :hp_below, condition_value: 99).valid?
    assert_not build_gambit(condition: :lowest_hp, condition_value: 50).valid?
    assert build_gambit(condition: :lowest_hp).valid?
  end

  test "condition_value is required within 1..99 for hp_above, within 1..20 for resource_at_least, and blank otherwise" do
    second_wind = { action_kind: :class_feature, target: :self, class_feature: class_features(:fighter_second_wind) }

    assert_not build_gambit(condition: :hp_above).valid?
    assert_not build_gambit(condition: :hp_above, condition_value: 0).valid?
    assert_not build_gambit(condition: :hp_above, condition_value: 100).valid?
    assert build_gambit(condition: :hp_above, condition_value: 1).valid?
    assert build_gambit(condition: :hp_above, condition_value: 99).valid?

    assert_not build_gambit(condition: :resource_at_least, **second_wind).valid?
    assert_not build_gambit(condition: :resource_at_least, condition_value: 0, **second_wind).valid?
    assert_not build_gambit(condition: :resource_at_least, condition_value: 21, **second_wind).valid?
    assert build_gambit(condition: :resource_at_least, condition_value: 20, **second_wind).valid?

    %i[highest_hp marked unmarked].each do |condition|
      assert build_gambit(condition:).valid?, condition
      assert_not build_gambit(condition:, condition_value: 50).valid?, condition
    end
  end

  test "resource_at_least is rejected with Ataque and with a cantrip, accepted with a leveled spell, a feature or a maneuver" do
    assert_includes build_gambit(condition: :resource_at_least, condition_value: 1).tap(&:validate).errors.attribute_names, :condition
    assert_includes build_gambit(condition: :resource_at_least, condition_value: 1, action_kind: :spell, spell: spells(:fire_bolt))
                      .tap(&:validate).errors.attribute_names, :condition
    assert build_gambit(condition: :resource_at_least, condition_value: 1, action_kind: :spell, spell: spells(:magic_missile)).valid?
    assert build_gambit(owner: player_characters(:battle_master_seven), condition: :resource_at_least, condition_value: 1,
                        action_kind: :class_feature, class_feature: class_features(:fighter_battle_master_maneuver_precision_attack)).valid?
    assert build_gambit(condition: :resource_at_least, condition_value: 1, action_kind: :class_feature, target: :self,
                        class_feature: class_features(:fighter_action_surge)).valid?
  end

  test "the condition enum keeps its stored integers" do
    assert_equal({ "any" => 0, "hp_below" => 1, "lowest_hp" => 2, "hp_above" => 3, "highest_hp" => 4, "marked" => 5,
                   "unmarked" => 6, "resource_at_least" => 7 }, Gambit.conditions)
  end

  test "label reads target, condition and action in Portuguese" do
    assert_equal "Inimigo: HP < 50% → Ataque", build_gambit(condition: :hp_below, condition_value: 50).label
    assert_equal "Self: qualquer → Second Wind",
                 build_gambit(action_kind: :class_feature, target: :self, class_feature: class_features(:fighter_second_wind)).label
    assert_equal "Inimigo: menor HP → Maneuver: Precision Attack",
                 build_gambit(condition: :lowest_hp, action_kind: :class_feature,
                              class_feature: class_features(:fighter_battle_master_maneuver_precision_attack)).label
    assert_equal "Inimigo: qualquer → Fire Bolt", build_gambit(action_kind: :spell, spell: spells(:fire_bolt)).label
    assert_equal "Inimigo: HP > 75% → Ataque", build_gambit(condition: :hp_above, condition_value: 75).label
    assert_equal "Inimigo: maior HP → Ataque", build_gambit(condition: :highest_hp).label
    assert_equal "Inimigo: marcado → Ataque", build_gambit(condition: :marked).label
    assert_equal "Inimigo: não marcado → Ataque", build_gambit(condition: :unmarked).label
    assert_equal "Self: recurso ≥ 1 → Action Surge",
                 build_gambit(action_kind: :class_feature, target: :self, condition: :resource_at_least, condition_value: 1,
                              class_feature: class_features(:fighter_action_surge)).label
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
