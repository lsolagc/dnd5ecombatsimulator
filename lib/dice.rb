# Rolagem de dados: Dice.roll(dice: "4d8", modifier: 2) e os atalhos Dice.d20 ... Dice.d100.
module Dice
  @@dice_calls = []

  def self.dice_calls
    r = {}
    for i in 0...@@dice_calls.size do
      r[i] = @@dice_calls[i].map(&:to_s)
    end

    r.to_json
  end

  def self.log_dice_call
    @@dice_calls << caller_locations.select { |i| i.to_s.include?("/workspaces/dnd/") }
  end

  def self.reset_dice_logs
    @@dice_calls = []
  end
  # Rola dice ("4d8") + modifier (Integer) e devolve um Dice::RollResult, com o valor de cada dado em rolls.
  # crit: regra do acerto crítico em .okf/architecture/combat-effect-pipeline.md
  def self.roll(dice:, modifier: 0, crit: false)
    dice = dice.to_s.downcase
    raise ArgumentError, "dice must be formatted like [number of dice]d[type of die] (e.g. 4d8)" unless dice.match?(/\d+d\d+/)
    raise ArgumentError, "modifier must be an Integer" unless modifier.is_a?(Integer)
    number_of_dice, max_value_of_die = dice.split("d").map(&:to_i)
    number_of_dice *= 2 if crit

    rolls = Array.new(number_of_dice) { rand(1..max_value_of_die) }
    natural = rolls.sum

    log_dice_call

    Dice::RollResult.new(natural:, total: natural + modifier, rolls:)
  end

  # Regra de acerto de um ataque (5e): .okf/architecture/combat-effect-pipeline.md
  def self.hit?(natural:, total:, armor_class:)
    natural == 20 || (natural != 1 && total >= armor_class)
  end

  # Rola 1d20 + modifier; o Dice::D20Roll re-rola uma vez com vantagem/desvantagem (#with_advantage/#with_disadvantage).
  def self.d20(modifier: 0)
    roll_result = roll(dice: "1d20", modifier:)
    total = roll_result.natural + modifier

    Dice::D20Roll.new(natural: roll_result.natural, total:, modifier:)
  end

  # Rola 1d12 + modifier (Integer) e devolve um Dice::RollResult.
  def self.d12(modifier: 0)
    roll_result = roll(dice: "1d12", modifier:)
    total = roll_result.natural + modifier

    Dice::RollResult.new(natural: roll_result.natural, total:)
  end

  # Rola 1d10 + modifier (Integer) e devolve um Dice::RollResult.
  def self.d10(modifier: 0)
    roll_result = roll(dice: "1d10", modifier:)
    total = roll_result.natural + modifier

    Dice::RollResult.new(natural: roll_result.natural, total:)
  end

  # Rola 1d8 + modifier (Integer) e devolve um Dice::RollResult.
  def self.d8(modifier: 0)
    roll_result = roll(dice: "1d8", modifier:)
    total = roll_result.natural + modifier

    Dice::RollResult.new(natural: roll_result.natural, total:)
  end

  # Rola 1d6 + modifier (Integer) e devolve um Dice::RollResult.
  def self.d6(modifier: 0)
    roll_result = roll(dice: "1d6", modifier:)
    total = roll_result.natural + modifier

    Dice::RollResult.new(natural: roll_result.natural, total:)
  end

  # Rola 1d4 + modifier (Integer) e devolve um Dice::RollResult.
  def self.d4(modifier: 0)
    roll_result = roll(dice: "1d4", modifier:)
    total = roll_result.natural + modifier

    Dice::RollResult.new(natural: roll_result.natural, total:)
  end

  # Rola 1d100 + modifier (Integer) e devolve um Dice::RollResult.
  def self.d100(modifier: 0)
    roll_result = roll(dice: "1d100", modifier:)
    total = roll_result.natural + modifier

    Dice::RollResult.new(natural: roll_result.natural, total:)
  end
end
