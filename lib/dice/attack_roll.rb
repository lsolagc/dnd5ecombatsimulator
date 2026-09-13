module Dice
  class AttackRoll
    attr_reader :total, :crit, :damage

    def initialize(to_hit_modifier: 0, damage_dice:, damage_modifier: 0, critical_hit_threshold: 20, advantage: false, disadvantage: false)
      @crit = false
      @critical_hit_threshold = critical_hit_threshold.to_i
      raise ArgumentError, "critical_hit_threshold must be between 1 and 20" unless @critical_hit_threshold.between?(1, 20)

      roll(to_hit_modifier:, advantage:, disadvantage:)

      @damage = Dice.roll(dice: damage_dice, modifier: damage_modifier, crit: @crit).total

      self
    end

    private
      def roll(to_hit_modifier:, advantage:, disadvantage:)
        first = Dice.d20(modifier: to_hit_modifier)

        roll_result =
          if advantage ^ disadvantage
            second = Dice.d20(modifier: to_hit_modifier)
            advantage ? [ first, second ].max_by(&:total) : [ first, second ].min_by(&:total)
          else
            first
          end

        @crit = true if roll_result.natural >= @critical_hit_threshold
        @total = roll_result.total
      end
  end
end
