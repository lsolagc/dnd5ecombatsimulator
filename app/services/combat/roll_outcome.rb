module Combat
  class RollOutcome
    attr_reader :expression, :resolved_expression, :dice, :rolls, :modifiers, :total

    def initialize(expression:, resolved_expression:, dice:, rolls:, modifiers:, total:)
      @expression = expression
      @resolved_expression = resolved_expression
      @dice = dice
      @rolls = rolls
      @modifiers = modifiers
      @total = total
    end
  end
end
