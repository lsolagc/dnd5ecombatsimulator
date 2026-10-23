require "test_helper"

class GambitOwnerTest < ActiveSupport::TestCase
  setup do
    @thorin = player_characters(:thorin)
    @preset = GambitPreset.create!(name: "Dono")
    @second_wind = class_features(:fighter_second_wind)
  end

  test "add_gambit appends at the next position and returns the gambit with its errors when it does not hold" do
    [ @thorin, @preset ].each do |owner|
      first = owner.add_gambit(target: :enemy, condition: :any, action_kind: :attack)
      second = owner.add_gambit(target: :enemy, condition: :lowest_hp, action_kind: :attack)

      assert first.persisted?
      assert_equal [ 1, 2 ], owner.gambits.reload.map(&:position)
      assert_equal second, owner.gambits.last

      invalid = owner.add_gambit(target: :self, condition: :any, action_kind: :attack)
      assert_not invalid.persisted?
      assert_includes invalid.errors.attribute_names, :target
    end
  end

  test "add_gambit refuses a seventh rule" do
    6.times { @preset.add_gambit(target: :enemy, condition: :any, action_kind: :attack) }

    seventh = @preset.add_gambit(target: :enemy, condition: :any, action_kind: :attack)
    assert_not seventh.persisted?
    assert_includes seventh.errors[:base].join, "No máximo 6"
  end

  test "move_gambit swaps with the neighbor and moves nothing at either end" do
    [ @thorin, @preset ].each do |owner|
      a, b, c = 3.times.map { owner.add_gambit(target: :enemy, condition: :any, action_kind: :attack) }

      owner.move_gambit(b, :up)
      assert_equal [ b, a, c ].map(&:id), owner.gambits.reload.ids
      owner.move_gambit(b, "up")
      owner.move_gambit(c, :down)
      assert_equal [ b, a, c ].map(&:id), owner.gambits.reload.ids
      owner.move_gambit(a, "down")
      assert_equal [ b, c, a ].map(&:id), owner.gambits.reload.ids
      assert_equal [ 1, 2, 3 ], owner.gambits.map(&:position)
    end
  end

  test "reorder_gambits accepts only an exact permutation of the owner's ids" do
    a, b, c = 3.times.map { @thorin.add_gambit(target: :enemy, condition: :any, action_kind: :attack) }
    other = @preset.add_gambit(target: :enemy, condition: :any, action_kind: :attack)

    [ [ a.id, b.id ], [ a.id, a.id, b.id ], [ a.id, b.id, other.id ], [ a.id, b.id, c.id, other.id ], [ a.id, b.id, c.id, c.id ] ].each do |ids|
      assert_not @thorin.reorder_gambits(ids), ids.inspect
      assert_equal [ a, b, c ].map(&:id), @thorin.gambits.reload.ids
    end

    assert @thorin.reorder_gambits([ c.id, a.id, b.id ])
    assert_equal [ [ c.id, 1 ], [ a.id, 2 ], [ b.id, 3 ] ], @thorin.gambits.reload.map { |gambit| [ gambit.id, gambit.position ] }
  end

  test "remove_gambit destroys the rule and compacts the positions" do
    [ @thorin, @preset ].each do |owner|
      a, b, c = 3.times.map { owner.add_gambit(target: :enemy, condition: :any, action_kind: :attack) }

      owner.remove_gambit(b)

      assert_not Gambit.exists?(b.id)
      assert_equal [ [ a.id, 1 ], [ c.id, 2 ] ], owner.gambits.reload.map { |gambit| [ gambit.id, gambit.position ] }
    end
  end

  test "remove_gambit refuses another owner's rule, changing nothing" do
    other = @preset.add_gambit(target: :enemy, condition: :any, action_kind: :attack)

    assert_raises(ActiveRecord::RecordNotFound) { @thorin.remove_gambit(other) }
    assert Gambit.exists?(other.id)
  end

  test "every write of the positions locks the owner's row first" do
    [ @thorin, @preset ].each do |owner|
      a, b = 2.times.map { owner.add_gambit(target: :enemy, condition: :any, action_kind: :attack) }
      writes = {
        add_gambit: -> { owner.add_gambit(target: :enemy, condition: :any, action_kind: :attack) },
        move_gambit: -> { owner.move_gambit(b, :up) },
        reorder_gambits: -> { owner.reorder_gambits(owner.gambits.reload.ids.reverse) },
        remove_gambit: -> { owner.remove_gambit(a) },
        replace_gambits: -> { owner.replace_gambits([ { target: :enemy, condition: :any, action_kind: :attack } ]) },
        copy_gambits_from: -> { owner.copy_gambits_from(owner == @preset ? @thorin : @preset) }
      }

      writes.each_value do |write|
        assert_queries_match(/FROM "#{owner.class.table_name}" WHERE .* FOR UPDATE/, &write)
      end
    end
  end

  test "copy_gambits_from works both ways and refuses an empty source, changing nothing" do
    kept = @thorin.add_gambit(target: :enemy, condition: :any, action_kind: :attack)

    assert_not @thorin.copy_gambits_from(@preset)
    assert_equal [ kept.id ], @thorin.gambits.reload.ids

    assert @preset.copy_gambits_from(@thorin)
    assert_equal [ "any" ], @preset.gambits.map(&:condition)
    assert @thorin.copy_gambits_from(@preset)
    assert_not Gambit.exists?(kept.id)
    assert_equal [ 1 ], @thorin.gambits.map(&:position)
  end

  test "copy_gambits_from raises on a rule that does not hold at the destination, changing nothing" do
    @second_wind.class_feature_unlocks.create!(level: 10, description: "Test: becomes an attack.",
                                               effect_payload: { kind: "damage", roll: "1d6", target: "enemy" })
    @preset.add_gambit(target: :enemy, condition: :lowest_hp, action_kind: :attack)
    @preset.add_gambit(target: :enemy, condition: :any, action_kind: :class_feature, class_feature: @second_wind)
    kept = @thorin.add_gambit(target: :enemy, condition: :any, action_kind: :attack)

    error = assert_raises(ActiveRecord::RecordInvalid) { @thorin.copy_gambits_from(@preset) }
    assert_equal 2, error.record.position
    assert_equal [ kept.id ], @thorin.gambits.reload.ids
  end

  test "replace_gambits puts the given rules at 1..n, or raises changing nothing" do
    kept = @preset.add_gambit(target: :enemy, condition: :any, action_kind: :attack)

    assert_raises(ActiveRecord::RecordInvalid) do
      @preset.replace_gambits([ { target: :enemy, condition: :any, action_kind: :attack },
                                { target: :enemy, condition: :hp_below, condition_value: 200, action_kind: :attack } ])
    end
    assert_equal [ kept.id ], @preset.gambits.reload.ids

    created = @preset.replace_gambits([ { target: :enemy, condition: :lowest_hp, action_kind: :attack },
                                        { "target" => "self", "condition" => "any", "action_kind" => "class_feature",
                                          "class_feature_id" => @second_wind.id } ])
    assert_equal created.map(&:id), @preset.gambits.ids
    assert_equal [ [ 1, "lowest_hp" ], [ 2, "any" ] ], @preset.gambits.map { |gambit| [ gambit.position, gambit.condition ] }
    assert_not Gambit.exists?(kept.id)
  end
end
