module Combat
  # Resolves a D&D 5e saving throw for a combat actor.
  #
  # No proficiency bonus is modeled today — only the raw ability modifier.
  class SavingThrow
    attr_reader :ability, :dc, :natural, :total, :success

    def initialize(actor:, ability:, dc:, advantage: false, disadvantage: false)
      @actor = actor
      @ability = ability.to_s
      @dc = dc.to_i

      roll(advantage:, disadvantage:)

      @success = @total >= @dc
    end

    private

      def roll(advantage:, disadvantage:)
        modifier = @actor.public_send("#{@ability}_modifier")
        first = Dice.d20(modifier:)

        chosen =
          if advantage ^ disadvantage
            second = Dice.d20(modifier:)
            advantage ? [ first, second ].max_by(&:total) : [ first, second ].min_by(&:total)
          else
            first
          end

        @natural = chosen.natural
        @total = chosen.total
      end
  end
end
