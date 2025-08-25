module Dice
  class AttackRoll
    attr_reader :total, :crit, :damage

    def initialize(to_hit_modifier: 0, damage_dice:, damage_modifier: 0)
      @crit = false
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
        @crit = true if roll_result.natural == 20
        @total = roll_result.total
      end
  end
end
