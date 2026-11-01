module Dice
  # A d20 roll that re-rolls once for advantage/disadvantage, a tie keeping itself: .okf/architecture/combat-effect-pipeline.md
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
