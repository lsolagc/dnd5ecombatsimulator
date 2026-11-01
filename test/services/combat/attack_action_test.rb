require "test_helper"
require "minitest/mock"

# The Attack action through the pipeline: CombatAction(:attack) → EffectResolver (weapon payload) →
# EffectExecutor (weapon attack roll + damage), repeated attacks_per_action times by ActionRunner.attack.
class Combat::AttackActionTest < ActiveSupport::TestCase
  setup do
    @attacker = player_characters(:aragorn) # strength 15 (mod +2)
    @attacker.combatant.assign_attributes(damage_dice: "1d8", damage_type: "slashing", attack_bonus: 3)
    @target = Combat::Participant.new(player_characters(:aragorn_copy))
    @other = Combat::Participant.new(player_characters(:thorin))
  end

  # Each Dice.d20 call takes the next natural from the list; every die rolls 4 (a crit rolls twice the dice).
  def with_rolls(*naturals, &)
    d20 = ->(modifier: 0) { natural = naturals.shift; Dice::D20Roll.new(natural:, total: natural + modifier, modifier:) }
    dice = lambda do |dice:, modifier: 0, crit: false|
      rolls = [ 4 ] * (dice.to_i * (crit ? 2 : 1))
      Dice::RollResult.new(natural: rolls.sum, total: rolls.sum + modifier, rolls:)
    end
    Dice.stub(:d20, d20) { Dice.stub(:roll, dice, &) }
  end

  def attack(next_target:, attacks: 1, **)
    @attacker.define_singleton_method(:attacks_per_action) { attacks }
    action = Combat::CombatAction.new(source_type: :attack, source_id: nil, actor: Combat::Participant.new(@attacker))
    Combat::ActionRunner.attack(action:, next_target:, **)
  end

  test "a hit adds weapon_attack_bonus to the d20 and deals the weapon's dice plus weapon_damage_modifier" do
    @target.character.combatant.armor_class = 0
    (_, result, _), = with_rolls(10) { attack(next_target: -> { @target }) }

    assert result.attack_roll.hit
    assert_equal 10 + @attacker.weapon_attack_bonus, result.attack_roll.total
    assert_equal 4 + @attacker.weapon_damage_modifier, result.amount
    assert_equal @target.max_hit_points - result.amount, @target.current_hit_points
  end

  test "attacks: 0 still makes one attack" do
    action = Combat::CombatAction.new(source_type: :attack, source_id: nil, actor: Combat::Participant.new(@attacker))
    made = with_rolls(10, 10) { Combat::ActionRunner.attack(action:, next_target: -> { @target }, attacks: 0) }

    assert_equal 1, made.size
  end

  test "Extra Attack: an attack after a kill goes to the next target, and the action ends when none is left" do
    @target = Combat::Participant.new(@target.character, hit_points: 1)
    picks = 0
    next_target = -> { picks += 1; [ @target, @other ].reject(&:dead?).first if picks <= 2 }

    attacks = with_rolls(15, 15, 15) { attack(next_target:, attacks: 3) }

    assert_equal [ @target, @other ], attacks.map(&:first), "the second attack must not be lost on the dead target"
    assert @target.dead?
    assert_equal 3, picks, "the third attack asks for a target, gets none and ends the action"
  end

  test "damage resistance follows the attacker's weapon type, not the target's own weapon" do
    @target.character.combatant.damage_type = "bludgeoning"
    @target.character.combatant.resistances["damage_types"]["slashing"] = true

    (_, result, _), = with_rolls(15) { attack(next_target: -> { @target }) }

    assert_equal (4 + @attacker.weapon_damage_modifier) / 2, @target.max_hit_points - @target.current_hit_points
    assert_equal 4 + @attacker.weapon_damage_modifier, result.amount, "the result reports the damage before resistance"
  end

  test "a weapon attack crits at the attacker's critical_hit_threshold; a spell attack only on a natural 20" do
    @attacker.define_singleton_method(:critical_hit_threshold) { 19 }
    @attacker.define_singleton_method(:spell_attack_bonus) { 0 } # Aragorn casts no spells

    (_, weapon, _), = with_rolls(19) { attack(next_target: -> { @target }) }
    spell = with_rolls(19) do
      Combat::EffectExecutor.call(effect: Combat::EffectInstance.new(kind: :damage, roll_expression: "1d8", target_type: "enemy", attack: "spell"),
                                  actor: Combat::Participant.new(@attacker), target: @target)
    end

    assert weapon.attack_roll.crit
    assert_equal 8 + @attacker.weapon_damage_modifier, weapon.amount, "a crit doubles the dice, never the modifier"
    refute spell.attack_roll.crit
  end

  test "natural 20 always hits and natural 1 always misses, whatever the target's AC" do
    @target.character.combatant.armor_class = 100
    (_, twenty, _), = with_rolls(20) { attack(next_target: -> { @target }) }
    @target.character.combatant.armor_class = 0
    (_, one, _), = with_rolls(1) { attack(next_target: -> { @target }) }

    assert twenty.attack_roll.hit
    refute one.attack_roll.hit
    assert_equal 0, one.amount
  end

  test "an attack with advantage rolls the d20 twice and keeps the higher" do
    (_, result, advantage), = with_rolls(3, 17) { attack(next_target: -> { @target }, advantage_against: ->(_target) { true }) }

    assert advantage
    assert_equal 17, result.attack_roll.natural
  end

  test "Fighting Style: Archery adds nothing on top of the sheet's final attack_bonus" do
    @attacker = player_characters(:fighter_archer)
    (_, result, _), = with_rolls(10) { attack(next_target: -> { @target }) }

    assert_equal 10 + 2, result.attack_roll.total
    assert_equal 2, @attacker.combatant.attack_bonus
  end

  test "Fighting Style: Dueling adds +2 to the weapon damage" do
    @attacker = player_characters(:fighter_duelist)
    @target.character.combatant.armor_class = 0
    (_, result, _), = with_rolls(10) { attack(next_target: -> { @target }) }

    assert result.attack_roll.hit
    assert_equal 4 + @attacker.strength_modifier + 2, result.amount
  end

  test "a hit that rolls 0 damage hits for nothing instead of raising" do
    @attacker.combatant.strength = 2 # STR mod -4: the stubbed 1d8 rolls 4, so the hit deals 4 - 4 = 0
    @target.character.combatant.armor_class = 0
    (_, result, _), = with_rolls(10) { attack(next_target: -> { @target }) }

    assert result.attack_roll.hit
    assert_equal 0, result.amount
    assert_equal @target.max_hit_points, @target.current_hit_points
  end

  test "a combatant with no configured weapon attacks with the 1d4 default" do
    action = Combat::CombatAction.new(source_type: :attack, source_id: nil, actor: player_characters(:aragorn_copy))

    assert_match(/\A1d4 /, Combat::EffectResolver.call(action:).first.roll_expression)
  end

  test "a malformed weapon die fails loudly instead of dealing 0 damage" do
    @attacker.combatant.damage_dice = "oops"

    error = assert_raises(ArgumentError) { attack(next_target: -> { @target }) }
    assert_match(/dice must be formatted/, error.message)
  end
end
