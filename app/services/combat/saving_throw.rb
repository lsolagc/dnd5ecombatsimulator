module Combat
  # A 5e saving throw by a combat actor: .okf/architecture/combat-effect-pipeline.md (Data shape: `effect_payload`)
  class SavingThrow
    attr_reader :ability, :dc, :natural, :total, :success, :rerolls_used

    # rerolls: the actor's Combat::Rerolls (Participant#rerolls_for), each used at most once, in order, while the
    # save fails; rerolls_used lists those it used, for the actor to spend (Participant#spend_rerolls!).
    def initialize(actor:, ability:, dc:, advantage: false, disadvantage: false, rerolls: [])
      @ability = ability.to_s
      @dc = dc.to_i
      @rerolls_used = []

      roll = Dice.d20(modifier: actor.public_send("#{@ability}_modifier"))
      roll = advantage ? roll.with_advantage : roll.with_disadvantage if advantage ^ disadvantage
      rerolls.each do |reroll|
        break if roll.total >= @dc
        next unless reroll.when == "failed"

        roll = roll.reroll_lower_die
        @rerolls_used << reroll
      end

      @natural = roll.natural
      @total = roll.total
      @success = @total >= @dc
    end

    def rerolled = rerolls_used.any?
  end
end
