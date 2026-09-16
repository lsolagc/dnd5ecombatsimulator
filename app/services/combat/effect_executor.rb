module Combat
  # Applies an EffectInstance to a combatant and returns a structured result.
  #
  # result fields:
  #   kind          - :heal | :damage
  #   applied       - true if the effect was applied
  #   amount        - effective HP change (always positive)
  #   hp_before     - target HP before the effect
  #   hp_after      - target HP after the effect
  #   roll_outcome  - Combat::RollOutcome with full roll breakdown
  #   saving_throw  - Combat::SavingThrow rolled by the target, or nil if the effect has no save
  #   message       - human-readable description
  class EffectExecutor
    Result = Data.define(:kind, :applied, :amount, :hp_before, :hp_after, :roll_outcome, :saving_throw, :message)

    def self.call(effect:, actor:, target:, combat_state: {}, reroll_saving_throw: false)
      new(effect:, actor:, target:, combat_state:, reroll_saving_throw:).execute
    end

    def initialize(effect:, actor:, target:, combat_state: {}, reroll_saving_throw: false)
      @effect               = effect
      @actor                = actor
      @target               = target
      @combat_state         = combat_state
      @reroll_saving_throw  = reroll_saving_throw
    end

    def execute
      actual_target = resolve_target

      case @effect.kind
      when :heal   then execute_heal(actual_target)
      when :damage then execute_damage(actual_target)
      else
        raise ArgumentError, "Unknown effect kind: #{@effect.kind}"
      end
    end

    private

      def resolve_target
        @effect.target_type == "self" ? @actor : @target
      end

      def execute_heal(target)
        hp_before                = target.current_hit_points || target.max_hit_points
        roll_outcome             = roll_for_effect
        full_amount              = [ roll_outcome.total, 0 ].max
        amount, saving_throw     = apply_save(full_amount:, target:)
        hp_after                 = [ hp_before + amount, target.max_hit_points ].min

        target.current_hit_points = hp_after

        Result.new(
          kind:         :heal,
          applied:      true,
          amount:       amount,
          hp_before:    hp_before,
          hp_after:     hp_after,
          roll_outcome: roll_outcome,
          saving_throw: saving_throw,
          message:      effect_message(verb: "heals", noun: "hit points", target:, amount:, roll_outcome:, saving_throw:)
        )
      end

      def execute_damage(target)
        hp_before             = target.current_hit_points || target.max_hit_points
        roll_outcome          = roll_for_effect
        full_amount           = [ roll_outcome.total, 0 ].max
        amount, saving_throw  = apply_save(full_amount:, target:)
        damage_type           = (@effect.damage_type || "bludgeoning").to_sym

        target.take_damage(amount: amount, damage_type: damage_type) if amount.positive?

        Result.new(
          kind:         :damage,
          applied:      true,
          amount:       amount,
          hp_before:    hp_before,
          hp_after:     target.current_hit_points,
          roll_outcome: roll_outcome,
          saving_throw: saving_throw,
          message:      effect_message(verb: "takes", noun: "#{damage_type} damage", target:, amount:, roll_outcome:, saving_throw:)
        )
      end

      def roll_for_effect
        context = RollContext.new(actor: @actor, target: @target, combat_state: @combat_state)
        RollExpression.new(expression: @effect.roll_expression).resolve(context:)
      end

      # Rolls the target's saving throw (if the effect declares one) and returns
      # the [effective_amount, saving_throw] pair. saving_throw is nil when the
      # effect has no save.
      def apply_save(full_amount:, target:)
        save = @effect.save
        return [ full_amount, nil ] unless save

        saving_throw = SavingThrow.new(actor: target, ability: save.fetch("ability"), dc: save.fetch("dc"), reroll_if_failed: @reroll_saving_throw)
        return [ full_amount, saving_throw ] unless saving_throw.success

        amount =
          case save["on_success"]
          when "negate" then 0
          when "half"   then full_amount / 2
          else full_amount
          end

        [ amount, saving_throw ]
      end

      def effect_message(verb:, noun:, target:, amount:, roll_outcome:, saving_throw:)
        base = "#{target.name} #{verb} #{amount} #{noun} (#{roll_outcome.resolved_expression})."
        return base unless saving_throw

        outcome = saving_throw.success ? "succeeds" : "fails"
        "#{base} #{target.name} #{outcome} the #{saving_throw.ability} save (DC #{saving_throw.dc})."
      end
  end
end
