module Combat
  # Applies an EffectInstance to a combatant and returns a structured result.
  #
  # result fields:
  #   kind         - :heal | :damage
  #   applied      - true if the effect was applied
  #   amount       - effective HP change (always positive)
  #   hp_before    - target HP before the effect
  #   hp_after     - target HP after the effect
  #   roll_outcome - Combat::RollOutcome with full roll breakdown
  #   message      - human-readable description
  class EffectExecutor
    Result = Data.define(:kind, :applied, :amount, :hp_before, :hp_after, :roll_outcome, :message)

    def self.call(effect:, actor:, target:, combat_state: {})
      new(effect:, actor:, target:, combat_state:).execute
    end

    def initialize(effect:, actor:, target:, combat_state: {})
      @effect       = effect
      @actor        = actor
      @target       = target
      @combat_state = combat_state
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
        hp_before    = target.current_hit_points || target.max_hit_points
        roll_outcome = roll_for_effect
        amount       = [ roll_outcome.total, 0 ].max
        hp_after     = [ hp_before + amount, target.max_hit_points ].min

        target.current_hit_points = hp_after

        Result.new(
          kind:         :heal,
          applied:      true,
          amount:       amount,
          hp_before:    hp_before,
          hp_after:     hp_after,
          roll_outcome: roll_outcome,
          message:      "#{target.name} heals #{amount} hit points (#{roll_outcome.resolved_expression})."
        )
      end

      def execute_damage(target)
        hp_before    = target.current_hit_points || target.max_hit_points
        roll_outcome = roll_for_effect
        amount       = [ roll_outcome.total, 0 ].max
        damage_type  = (@effect.damage_type || "bludgeoning").to_sym

        target.take_damage(amount: amount, damage_type: damage_type)

        Result.new(
          kind:         :damage,
          applied:      true,
          amount:       amount,
          hp_before:    hp_before,
          hp_after:     target.current_hit_points,
          roll_outcome: roll_outcome,
          message:      "#{target.name} takes #{amount} #{damage_type} damage (#{roll_outcome.resolved_expression})."
        )
      end

      def roll_for_effect
        context = RollContext.new(actor: @actor, target: @target, combat_state: @combat_state)
        RollExpression.new(expression: @effect.roll_expression).resolve(context:)
      end
  end
end
