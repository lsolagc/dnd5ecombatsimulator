require "test_helper"

class ClassFeatureTest < ActiveSupport::TestCase
  setup do
    @fighter = player_classes(:fighter)
  end

  test "valid feature" do
    feature = ClassFeature.new(
      player_class: @fighter,
      name: "Indomitable",
      slug: "indomitable",
      description: "Reroll one failed saving throw.",
      feature_type: :core,
      action_type: :no_action,
      recharge_type: :long_rest,
      grants_spellcasting: false,
      source_book: "PHB 2014"
    )

    assert feature.valid?
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
