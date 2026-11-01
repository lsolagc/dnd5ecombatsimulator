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

  test "an effect payload, when present, fits the effect vocabulary, its save included" do
    error_for = lambda do |payload|
      Spell.new(name: "Burst", slug: "burst", level: 1, school: "evocation", description: "x", effect_payload: payload).tap(&:valid?).errors[:effect_payload]
    end
    burst = { kind: "damage", roll: "2d6", target: "enemy", save: { ability: "dexterity", dc: "spell", on_success: "half" } }
    with_save = ->(changes) { burst.merge(save: burst[:save].merge(changes)) }

    assert_empty error_for.(nil)
    assert_empty error_for.(burst)
    assert_equal [ "has an unknown kind: \"teleport\"" ], error_for.({ kind: "teleport" })
    assert_equal [ "is missing save.ability" ], error_for.(burst.merge(save: burst[:save].except(:ability)))
    assert_equal [ "is missing save.dc" ], error_for.(burst.merge(save: burst[:save].except(:dc)))
    assert_equal [ "is missing save.on_success" ], error_for.(burst.merge(save: burst[:save].except(:on_success)))
    assert_equal [ "save.ability must be one of #{AbilityScores::ABILITY_SCORE_COLUMNS.join(', ')}" ], error_for.(with_save.(ability: "agility"))
    [ 0, 31, "10", 10.5 ].each do |dc|
      assert_equal [ "save.dc must be an integer from 1 to 30 or spell" ], error_for.(with_save.(dc:)), "dc #{dc.inspect}"
    end
    assert_empty error_for.(with_save.(dc: 30))
    assert_equal [ "save.on_success must be one of half, negate" ], error_for.(with_save.(on_success: "halff"))
  end

  test "every fixture and seed spell fits the effect vocabulary" do
    SeedData.load_all

    assert Spell.where.not(effect_payload: nil).exists?
    assert_empty Spell.all.reject(&:valid?).map { |spell| "#{spell.slug}: #{spell.errors.full_messages}" }
  end
end
