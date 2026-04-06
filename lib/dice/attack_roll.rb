module Dice
  class AttackRoll
    attr_reader :total, :crit, :damage

    def initialize(to_hit_modifier: 0, damage_dice:, damage_modifier: 0, critical_hit_threshold: 20)
      @crit = false
      @critical_hit_threshold = critical_hit_threshold.to_i
      raise ArgumentError, "critical_hit_threshold must be between 1 and 20" unless @critical_hit_threshold.between?(1, 20)

      roll(to_hit_modifier:)

      @damage = Dice.roll(dice: damage_dice, modifier: damage_modifier, crit: @crit).total

      self
    end

    def self.with_advantage(to_hit_modifier: 0)
      [ new(to_hit_modifier:), new(to_hit_modifier:) ].max_by { |atk| atk.total }
    end

    def self.with_disadvantage(to_hit_modifier: 0)
      [ new(to_hit_modifier:), new(to_hit_modifier:) ].min_by { |atk| atk.total }
    end

    private
      def roll(to_hit_modifier:)
        roll_result = Dice.d20(modifier: to_hit_modifier)
        @crit = true if roll_result.natural >= @critical_hit_threshold
        @total = roll_result.total
      end
  end
end
