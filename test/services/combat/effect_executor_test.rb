require "test_helper"

class Combat::EffectExecutorTest < ActiveSupport::TestCase
  setup do
    @fighter = player_characters(:aragorn) # max_hit_points: 12, strength: 15 (mod +2)
    @fighter.current_hit_points = 5
  end

  test "heal effect increases target HP" do
    Random.srand(1)
    effect = Combat::EffectInstance.new(kind: :heal, roll_expression: "1d4", target_type: "self")

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: @fighter)

    assert_equal :heal, result.kind
    assert result.applied
    assert_equal 5, result.hp_before
    assert result.hp_after > 5
    assert result.hp_after <= @fighter.max_hit_points
  end

  test "heal effect caps at max HP" do
    @fighter.current_hit_points = 11 # 1 below max

    effect = Combat::EffectInstance.new(kind: :heal, roll_expression: "1d10", target_type: "self")

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: @fighter)

    assert_equal @fighter.max_hit_points, result.hp_after
  end

  test "heal effect includes roll_outcome breakdown" do
    Random.srand(1)
    effect = Combat::EffectInstance.new(kind: :heal, roll_expression: "1d10 + actor_level", target_type: "self")

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: @fighter)

    assert_instance_of Combat::RollOutcome, result.roll_outcome
    assert_equal "1d10 + actor_level", result.roll_outcome.expression
    assert result.roll_outcome.total >= 2 # min 1d10(1) + level(1)
  end

  test "heal effect returns a descriptive message" do
    Random.srand(1)
    effect = Combat::EffectInstance.new(kind: :heal, roll_expression: "1d4", target_type: "self")

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: @fighter)

    assert_includes result.message, @fighter.name
    assert_includes result.message, "heals"
  end

  test "damage effect reduces target HP" do
    Random.srand(1)
    effect = Combat::EffectInstance.new(
      kind: :damage,
      roll_expression: "1d4",
      target_type: "target",
      damage_type: "fire"
    )
    target = player_characters(:aragorn_copy)
    target.current_hit_points = target.max_hit_points

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: target)

    assert_equal :damage, result.kind
    assert result.hp_after < result.hp_before
  end

  test "damage effect defaults to bludgeoning damage type" do
    target = player_characters(:aragorn_copy)
    target.current_hit_points = target.max_hit_points
    hp_before = target.current_hit_points

    effect = Combat::EffectInstance.new(kind: :damage, roll_expression: "1d4", target_type: "target")

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: target)

    assert result.hp_after < hp_before
  end

  test "raises for unknown effect kind" do
    effect = Combat::EffectInstance.new(kind: :unknown_kind, roll_expression: "1d4", target_type: "self")

    assert_raises(ArgumentError) do
      Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: @fighter)
    end
  end

  test "damage effect with a save applies full damage when the target fails" do
    Random.srand(1) # 1d10 roll = 6, target's dexterity save total = 13
    effect = Combat::EffectInstance.new(
      kind: :damage,
      roll_expression: "1d10",
      target_type: "target",
      save: { "ability" => "dexterity", "dc" => 20, "on_success" => "half" }
    )
    target = player_characters(:aragorn_copy)
    target.current_hit_points = target.max_hit_points

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: target)

    refute result.saving_throw.success
    assert_equal 6, result.amount
    assert_includes result.message, "fails the dexterity save"
  end

  test "damage effect with a save applies half damage when the target succeeds" do
    Random.srand(1) # 1d10 roll = 6, target's dexterity save total = 13
    effect = Combat::EffectInstance.new(
      kind: :damage,
      roll_expression: "1d10",
      target_type: "target",
      save: { "ability" => "dexterity", "dc" => 5, "on_success" => "half" }
    )
    target = player_characters(:aragorn_copy)
    target.current_hit_points = target.max_hit_points

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: target)

    assert result.saving_throw.success
    assert_equal 3, result.amount
    assert_includes result.message, "succeeds the dexterity save"
  end

  test "damage effect with a save negates damage entirely on success" do
    Random.srand(1) # 1d10 roll = 6, target's dexterity save total = 13
    effect = Combat::EffectInstance.new(
      kind: :damage,
      roll_expression: "1d10",
      target_type: "target",
      save: { "ability" => "dexterity", "dc" => 5, "on_success" => "negate" }
    )
    target = player_characters(:aragorn_copy)
    hp_before = target.current_hit_points = target.max_hit_points

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: target)

    assert result.saving_throw.success
    assert_equal 0, result.amount
    assert_equal hp_before, result.hp_after
  end

  test "reroll_saving_throw reflects the second roll when the first save fails" do
    Random.srand(26) # 1d10 roll = 6; 1st dexterity save total 8 (fails dc 10); reroll total 18 (succeeds)
    effect = Combat::EffectInstance.new(
      kind: :damage,
      roll_expression: "1d10",
      target_type: "target",
      save: { "ability" => "dexterity", "dc" => 10, "on_success" => "half" }
    )
    target = player_characters(:aragorn_copy)
    target.current_hit_points = target.max_hit_points

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: target, reroll_saving_throw: true)

    assert result.saving_throw.rerolled
    assert result.saving_throw.success
    assert_equal 3, result.amount
  end

  test "reroll_saving_throw does not reroll a save that succeeds on the first attempt" do
    Random.srand(1) # 1d10 roll = 6; dexterity save total 13, succeeds dc 5 on the first attempt
    effect = Combat::EffectInstance.new(
      kind: :damage,
      roll_expression: "1d10",
      target_type: "target",
      save: { "ability" => "dexterity", "dc" => 5, "on_success" => "half" }
    )
    target = player_characters(:aragorn_copy)
    target.current_hit_points = target.max_hit_points

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: target, reroll_saving_throw: true)

    refute result.saving_throw.rerolled
    assert_equal 3, result.amount
  end

  # spell attack / spell save DC

  test "a spell attack that beats the target's AC deals damage and reports the attack roll" do
    result = cast_spell_effect(attack: "spell", target_armor_class: 0, seed: 2) # d20 = 9 (total 15), 1d10 = 9

    assert result.applied
    assert result.attack_roll.hit
    refute result.attack_roll.crit
    assert_equal 6, result.attack_roll.total - result.attack_roll.natural # proficiency +3, INT +3
    assert_equal 9, result.amount
    assert_includes result.message, "Spell attack 15 vs AC 0: hit"
  end

  test "a spell attack that misses deals no damage" do
    result = cast_spell_effect(attack: "spell", target_armor_class: 100, seed: 2) # d20 = 9 (total 15)

    refute result.applied
    refute result.attack_roll.hit
    assert_equal 0, result.amount
    assert_equal result.hp_before, result.hp_after
    assert_includes result.message, "miss"
  end

  test "a natural 20 on a spell attack always hits, even past the target's AC, and doubles the damage dice" do
    result = cast_spell_effect(attack: "spell", target_armor_class: 100, seed: 23) # d20 = 20 (total 26 < AC 100), 1d10 = 7

    assert result.applied
    assert result.attack_roll.hit
    assert result.attack_roll.crit
    assert_equal 14, result.amount
    assert_includes result.message, "critical hit"
  end

  test "a natural 1 on a spell attack always misses, even when the total beats the target's AC" do
    result = cast_spell_effect(attack: "spell", target_armor_class: 0, seed: 41) # d20 = 1 (total 7 > AC 0)

    refute result.applied
    refute result.attack_roll.hit
    refute result.attack_roll.crit
    assert_equal 0, result.amount
    assert_includes result.message, "miss"
  end

  test "an effect without an attack type never rolls a spell attack" do
    assert_nil cast_spell_effect(attack: nil, target_armor_class: 100).attack_roll
  end

  test "a save whose dc is 'spell' uses the caster's spell save DC" do
    result = cast_spell_effect(save: { "ability" => "dexterity", "dc" => "spell", "on_success" => "half" })

    assert_equal 14, result.saving_throw.dc # 8 + 3 + 3
  end

  test "an unsupported attack type is rejected" do
    assert_raises(ArgumentError) do
      Combat::EffectInstance.new(kind: :damage, roll_expression: "1d10", target_type: "target", attack: "melee")
    end
  end

  test "heal effect without a save leaves saving_throw nil" do
    Random.srand(1)
    effect = Combat::EffectInstance.new(kind: :heal, roll_expression: "1d4", target_type: "self")

    result = Combat::EffectExecutor.call(effect: effect, actor: @fighter, target: @fighter)

    assert_nil result.saving_throw
  end

  private

    # Casts a 1d10 damage effect from an Eldritch Knight (level 5: proficiency +3, INT 16 = +3).
    def cast_spell_effect(attack: nil, save: nil, target_armor_class: 10, seed: nil)
      caster = PlayerCharacter.create!(
        name: "Caster", level: 5, player_class: player_classes(:fighter),
        martial_archetype: class_features(:fighter_eldritch_knight_archetype),
        combatant_attributes: { intelligence: 16 }
      )
      ClassLevelProgression.find_or_create_by!(player_class: caster.player_class, level: 5) do |progression|
        progression.proficiency_bonus = 3
      end
      target = player_characters(:aragorn_copy)
      target.combatant.update!(armor_class: target_armor_class)
      target.current_hit_points = target.max_hit_points

      effect = Combat::EffectInstance.new(kind: :damage, roll_expression: "1d10", target_type: "target", attack:, save:)
      Random.srand(seed) if seed
      Combat::EffectExecutor.call(effect:, actor: caster, target:)
    end
end
