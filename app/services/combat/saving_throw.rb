module Combat
  # A 5e saving throw by a combat actor: .okf/architecture/combat-effect-pipeline.md (Data shape: `effect_payload`)
  class SavingThrow
    attr_reader :ability, :dc, :natural, :total, :success, :rerolled

    def initialize(actor:, ability:, dc:, advantage: false, disadvantage: false, reroll_if_failed: false)
      @actor = actor
      @ability = ability.to_s
      @dc = dc.to_i
      @rerolled = false

      roll(advantage:, disadvantage:)
      @success = @total >= @dc

      if !@success && reroll_if_failed
        roll(advantage:, disadvantage:)
        @success = @total >= @dc
        @rerolled = true
      end
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
