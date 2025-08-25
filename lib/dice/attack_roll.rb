module Dice
  class AttackRoll
    attr_reader :total, :crit, :damage

    def initialize(modifier: 0, damage_dice:)
      @crit = false
      roll(modifier:)

      @damage = Dice.roll(dice: damage_dice, crit: @crit).total

      self
    end

    def self.with_advantage(modifier: 0)
      [ new(modifier:), new(modifier:) ].max_by { |atk| atk.total }
    end

    def self.with_disadvantage(modifier: 0)
      [ new(modifier:), new(modifier:) ].min_by { |atk| atk.total }
    end

    private
      def roll(modifier:)
        roll_result = Dice.d20(modifier:)
        @crit = true if roll_result.natural == 20
        @total = roll_result.total
      end
  end
end
