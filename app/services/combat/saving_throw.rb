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
        roll_result = Dice.d20(modifier:)
        roll_result = advantage ? roll_result.with_advantage : roll_result.with_disadvantage if advantage ^ disadvantage

        @natural = roll_result.natural
        @total = roll_result.total
      end
  end
end
