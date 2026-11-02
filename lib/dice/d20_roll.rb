module Dice
  # A d20 roll that re-rolls once for advantage/disadvantage, rolls holding both dice: .okf/architecture/combat-effect-pipeline.md
  class D20Roll < RollResult
    # advantage: true with advantage, false with disadvantage, nil a single die.
    def initialize(natural:, total:, modifier:, rolls: [ natural ], advantage: nil)
      super(natural:, total:, rolls:)
      @modifier = modifier
      @advantage = advantage
    end

    def with_advantage = paired_with(Dice.d20(modifier: @modifier).natural, advantage: true)

    def with_disadvantage = paired_with(Dice.d20(modifier: @modifier).natural, advantage: false)

    # Rerolls one die, the lower (5e): with disadvantage the one that counts, with advantage the only one that can
    # improve; the higher stays. A single die is just rolled again.
    def reroll_lower_die
      fresh = Dice.d20(modifier: @modifier)
      return fresh if @advantage.nil?

      D20Roll.new(natural: rolls.max, total: rolls.max + @modifier, modifier: @modifier).paired_with(fresh.natural, advantage: @advantage)
    end

    protected

      def paired_with(other_natural, advantage:)
        dice = [ natural, other_natural ]
        kept = advantage ? dice.max : dice.min
        D20Roll.new(natural: kept, total: kept + @modifier, modifier: @modifier, rolls: dice, advantage:)
      end
  end
end
