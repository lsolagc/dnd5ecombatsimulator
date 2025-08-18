module Dice
  class AttackRoll
    attr_reader :total, :crit

    def initialize(modifier: 0)
      @crit = false
      roll(modifier:)

      self
    end

    private
      def roll(modifier:)
        roll_result = Dice.d20(modifier:)
        @crit = true if roll_result.natural == 20
        @total = roll_result.total
      end
  end
end
