# Dice
#
# Classe utilitária para rolagem de dados em sistemas de RPG.
#
# Exemplos de uso:
#
#   Dice.roll(dice: '4d8', modifier: 2)
#   Dice.d20(modifier: 1)
#
# Todos os métodos retornam uma instância de Dice::RollResult.
#
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
  # Rola qualquer combinação de dados no formato "[quantidade]d[tipo]" com modificador opcional.
  #
  # @param dice [String] Ex: '2d6', '4d8'
  # @param modifier [Integer] Modificador a ser somado ao resultado total
  # @return [Dice::RollResult] Resultado da rolagem
  def self.roll(dice:, modifier: 0, crit: false)
    # generic roll, called like Dice.roll(dice: '4d8', modifier: 4)
    dice = dice.to_s.downcase
    raise ArgumentError, "dice must be formatted like [number of dice]d[type of die] (e.g. 4d8)" unless dice.match?(/\d+d\d+/)
    raise ArgumentError, "modifier must be an Integer" unless modifier.is_a?(Integer)
    number_of_dice, max_value_of_die = dice.split("d").map(&:to_i)

    dice_rolls = 0
    number_of_dice.times do
      dice_rolls += rand(1..max_value_of_die)
    end

    dice_rolls = dice_rolls * 2 if crit
    total_roll_value = dice_rolls + modifier

    log_dice_call

    Dice::RollResult.new(natural: dice_rolls, total: total_roll_value)
  end

  # Rola um dado d20 com modificador opcional.
  #
  # @param modifier [Integer] Modificador a ser somado ao resultado
  # @return [Dice::RollResult]
  def self.d20(modifier: 0)
    roll_result = roll(dice: "1d20", modifier:)
    total = roll_result.natural + modifier

    Dice::RollResult.new(natural: roll_result.natural, total:)
  end

  # Rola um dado d12 com modificador opcional.
  #
  # @param modifier [Integer]
  # @return [Dice::RollResult]
  def self.d12(modifier: 0)
    roll_result = roll(dice: "1d12", modifier:)
    total = roll_result.natural + modifier

    Dice::RollResult.new(natural: roll_result.natural, total:)
  end

  # Rola um dado d10 com modificador opcional.
  #
  # @param modifier [Integer]
  # @return [Dice::RollResult]
  def self.d10(modifier: 0)
    roll_result = roll(dice: "1d10", modifier:)
    total = roll_result.natural + modifier

    Dice::RollResult.new(natural: roll_result.natural, total:)
  end

  # Rola um dado d8 com modificador opcional.
  #
  # @param modifier [Integer]
  # @return [Dice::RollResult]
  def self.d8(modifier: 0)
    roll_result = roll(dice: "1d8", modifier:)
    total = roll_result.natural + modifier

    Dice::RollResult.new(natural: roll_result.natural, total:)
  end

  # Rola um dado d6 com modificador opcional.
  #
  # @param modifier [Integer]
  # @return [Dice::RollResult]
  def self.d6(modifier: 0)
    roll_result = roll(dice: "1d6", modifier:)
    total = roll_result.natural + modifier

    Dice::RollResult.new(natural: roll_result.natural, total:)
  end

  # Rola um dado d4 com modificador opcional.
  #
  # @param modifier [Integer]
  # @return [Dice::RollResult]
  def self.d4(modifier: 0)
    roll_result = roll(dice: "1d4", modifier:)
    total = roll_result.natural + modifier

    Dice::RollResult.new(natural: roll_result.natural, total:)
  end

  # Rola um dado d100 com modificador opcional.
  #
  # @param modifier [Integer]
  # @return [Dice::RollResult]
  def self.d100(modifier: 0)
    roll_result = roll(dice: "1d100", modifier:)
    total = roll_result.natural + modifier

    Dice::RollResult.new(natural: roll_result.natural, total:)
  end
end
