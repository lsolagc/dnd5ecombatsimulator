require "test_helper"

class ClassFeatureTest < ActiveSupport::TestCase
  setup do
    @fighter = player_classes(:fighter)
  end

  test "valid feature" do
    feature = ClassFeature.new(
      player_class: @fighter,
      name: "Test Feature",
      slug: "test-feature",
      description: "A generic feature used only to test validity.",
      feature_type: :core,
      action_type: :no_action,
      recharge_type: :long_rest,
      grants_spellcasting: false,
      source_book: "PHB 2014"
    )

    assert feature.valid?
  end

  test "the effect in force at a level is the highest unlock's at or below it that has one; with no level, the highest" do
    second_wind = class_features(:fighter_second_wind)
    ClassFeatureUnlock.create!(class_feature: second_wind, level: 10, description: "Test: becomes an attack.",
                               effect_payload: { kind: "damage", roll: "1d6", target: "enemy" })
    ClassFeatureUnlock.create!(class_feature: second_wind, level: 15, description: "Test: no effect of its own.")
    ClassFeatureUnlock.create!(class_feature: second_wind, level: 17, description: "Test: a passive.",
                               effect_payload: { kind: "heal", roll: "1", target: "self", trigger: "turn_start" })
    kind_at = ->(level) { second_wind.effect_payload_at(level)&.fetch("kind") }

    assert_equal %w[heal heal damage damage heal], [ 1, 9, 10, 15, 17 ].map(&kind_at)
    assert_equal "heal", kind_at.(nil)
    assert_nil second_wind.effect_payload_at(0)
    assert_equal %w[self self enemy enemy], [ 1, 9, 10, 16 ].map { |level| second_wind.action_payload_at(level)["target"] }
    assert_nil second_wind.action_payload_at(17), "a triggered passive is not a turn action"
    assert_nil second_wind.action_payload_at, "nor at the highest level"
  end

  test "a spellcasting feature needs a spellcasting ability of its own when the class has none" do
    attrs = { name: "Subclass Casting", slug: "subclass-casting", description: "Casts.", feature_type: :core,
              action_type: :passive, recharge_type: :none, grants_spellcasting: true, source_book: "PHB 2014" }

    feature = ClassFeature.new(attrs.merge(player_class: @fighter))
    assert_not feature.valid?
    assert_includes feature.errors.attribute_names, :spellcasting_ability

    assert ClassFeature.new(attrs.merge(player_class: @fighter, spellcasting_ability: :intelligence)).valid?
    assert ClassFeature.new(attrs.merge(player_class: player_classes(:wizard))).valid? # class supplies it
  end

  test "requires name slug and description" do
    feature = ClassFeature.new(player_class: @fighter)

    assert_not feature.valid?
    assert_includes feature.errors[:name], "can't be blank"
    assert_includes feature.errors[:slug], "can't be blank"
    assert_includes feature.errors[:description], "can't be blank"
  end

  test "slug is unique per class" do
    duplicate = ClassFeature.new(
      player_class: @fighter,
      name: "Second Wind Copy",
      slug: class_features(:fighter_second_wind).slug,
      description: "Duplicate slug",
      feature_type: :core,
      action_type: :bonus_action,
      recharge_type: :short_or_long_rest,
      grants_spellcasting: false,
      source_book: "PHB 2014"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "same slug can exist in another class" do
    wizard = player_classes(:wizard)
    feature = ClassFeature.new(
      player_class: wizard,
      name: "Second Wind (homebrew)",
      slug: class_features(:fighter_second_wind).slug,
      description: "Allowed because it belongs to another class.",
      feature_type: :optional,
      action_type: :bonus_action,
      recharge_type: :short_or_long_rest,
      grants_spellcasting: false,
      source_book: "Homebrew"
    )

    assert feature.valid?
  end
end
