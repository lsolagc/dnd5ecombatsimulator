require "test_helper"

class SpellTest < ActiveSupport::TestCase
  test "valid spell" do
    spell = Spell.new(
      name: "Ray of Frost",
      slug: "ray-of-frost",
      level: 0,
      school: "evocation",
      description: "A frigid beam of blue-white light streaks toward a creature."
    )

    assert spell.valid?
  end

  test "requires name slug school and description" do
    spell = Spell.new

    assert_not spell.valid?
    assert_includes spell.errors[:name], "can't be blank"
    assert_includes spell.errors[:slug], "can't be blank"
    assert_includes spell.errors[:school], "can't be blank"
    assert_includes spell.errors[:description], "can't be blank"
  end

  test "slug is globally unique" do
    duplicate = Spell.new(
      name: "Fire Bolt Copy",
      slug: spells(:fire_bolt).slug,
      level: 0,
      school: "evocation",
      description: "Duplicate slug"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "level must be between 0 and 9" do
    spell = Spell.new(name: "Bad Level", slug: "bad-level", level: 10, school: "evocation", description: "x")

    assert_not spell.valid?
    assert_includes spell.errors[:level], "must be less than or equal to 9"
  end

  test "cantrip? is true only for level 0 spells" do
    assert spells(:fire_bolt).cantrip?
    assert_not spells(:magic_missile).cantrip?
  end
end
