require "test_helper"

class GambitPresetTest < ActiveSupport::TestCase
  setup do
    @thorin = player_characters(:thorin)
    @second_wind = class_features(:fighter_second_wind)
  end

  test "the name is required, stripped and unique regardless of case" do
    assert_equal "Tanque", GambitPreset.create!(name: "  Tanque ").name

    assert_not GambitPreset.new(name: "   ").valid?
    duplicate = GambitPreset.new(name: " tANQUE")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "Já existe um preset com esse nome"
  end

  test "the database refuses a name differing only in case" do
    GambitPreset.create!(name: "Tanque")

    assert_raises(ActiveRecord::RecordNotUnique) { GambitPreset.new(name: "TANQUE").save!(validate: false) }
  end

  test "a preset owns up to six gambits, like a character, and destroys them with itself" do
    preset = GambitPreset.create!(name: "Cheio")
    6.times { |index| Gambit.create!(owner: preset, position: index + 1, target: :enemy, condition: :any, action_kind: :attack) }

    seventh = Gambit.new(owner: preset.reload, position: 6, target: :enemy, condition: :any, action_kind: :attack)
    assert_not seventh.valid?
    assert_includes seventh.errors[:base].join, "No máximo 6"
    assert_difference("Gambit.count", -6) { preset.destroy }
  end

  test "copy_gambits_from replaces the destination with new rows copying every attribute, in priority order" do
    # Created out of position order, so the ids do not follow the priority.
    second = rule(@thorin, position: 2, target: :self, condition: :hp_below, condition_value: 40, action_kind: :class_feature,
      class_feature: @second_wind, enabled: false)
    first = rule(@thorin, position: 1, target: :enemy, condition: :lowest_hp, action_kind: :attack)
    third = rule(@thorin, position: 3, target: :enemy, condition: :any, action_kind: :spell, spell: spells(:fire_bolt))
    preset = GambitPreset.create!(name: "Thorin")
    stale = rule(preset, position: 1, target: :enemy, condition: :marked, action_kind: :attack)

    assert preset.copy_gambits_from(@thorin)

    assert_not Gambit.exists?(stale.id), "the destination's old rules are deleted"
    assert_equal rules_of(@thorin), rules_of(preset)
    assert_equal [ 1, 2, 3 ], preset.gambits.map(&:position)
    assert_equal [ "lowest_hp", "hp_below", "any" ], preset.gambits.map(&:condition)
    assert_empty preset.gambits.ids & [ first, second, third ].map(&:id), "copies are new rows"
    assert_equal [ first, second, third ].map(&:id), @thorin.gambits.reload.ids, "the source is untouched"
  end

  test "copy_gambits_from compacts the source's positions in their order" do
    rule(@thorin, position: 5, target: :enemy, condition: :lowest_hp, action_kind: :attack)
    rule(@thorin, position: 2, target: :enemy, condition: :any, action_kind: :attack)
    preset = GambitPreset.create!(name: "Lacunas")

    preset.copy_gambits_from(@thorin)

    assert_equal [ [ 1, "any" ], [ 2, "lowest_hp" ] ], preset.gambits.map { |gambit| [ gambit.position, gambit.condition ] }
  end

  test "copying twice replaces instead of accumulating" do
    rule(@thorin, position: 1, target: :enemy, condition: :any, action_kind: :attack)
    rule(@thorin, position: 2, target: :self, condition: :any, action_kind: :class_feature, class_feature: @second_wind)
    preset = GambitPreset.create!(name: "Duas vezes")

    2.times { preset.copy_gambits_from(@thorin) }

    assert_equal 2, Gambit.where(owner: preset).count
  end

  test "an empty source is refused and the destination keeps its rules" do
    preset = GambitPreset.create!(name: "Cheio")
    kept = rule(preset, position: 1, target: :enemy, condition: :any, action_kind: :attack)

    assert_not preset.copy_gambits_from(@thorin)
    assert_equal [ kept.id ], preset.gambits.reload.ids
  end

  private

    def rule(owner, **attributes)
      Gambit.create!(owner:, **attributes)
    end

    def rules_of(owner)
      Gambit.where(owner:).order(:position).map { |gambit| gambit.attributes.slice(*Gambit::SNAPSHOT_ATTRIBUTES) }
    end
end
