module Dice
  # A d20 roll that can re-roll itself once for advantage/disadvantage, keeping
  # whichever total wins (ties keep the original roll, matching [a, b].max_by/min_by).
  #
  # Advantage/disadvantage in 5e only ever apply to d20 rolls (attacks, saves,
  # ability checks), so this lives next to Dice.d20 rather than as a generic
  # wrapper for every kind of die.
  class D20Roll < RollResult
    def initialize(natural:, total:, modifier:)
      super(natural:, total:)
      @modifier = modifier
    end

    def with_advantage
      better_of(Dice.d20(modifier: @modifier))
    end

    def with_disadvantage
      worse_of(Dice.d20(modifier: @modifier))
    end

    private

      def better_of(other)
        total >= other.total ? self : other
      end

      def worse_of(other)
        total <= other.total ? self : other
      end
  end
end
