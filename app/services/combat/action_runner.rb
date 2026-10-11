module Combat
  # Orchestrates the full pipeline: CombatAction → EffectResolver → EffectExecutor.
  #
  # Returns an array of EffectExecutor::Result, one per resolved EffectInstance.
  class ActionRunner
    def self.call(action:, reroll_saving_throw: false, disadvantage_on_save: false, crit: false)
      effects = EffectResolver.call(action:)

      effects.map do |effect|
        target = effect.target_type == "self" ? action.actor : action.targets.first
        EffectExecutor.call(effect:, actor: action.actor, target:, reroll_saving_throw:, disadvantage_on_save:, crit:)
      end
    end

    # The Attack action: up to attacks_per_action weapon attacks (Extra Attack), each with its own target.
    # Before each attack next_target names the target, so an attack after a kill goes to someone else; nil
    # ends the action early. advantage_against(target) says whether that attack rolls with advantage. The
    # block sees each attack (target, result, advantage) before the next target is picked.
    # Returns the [target, result, advantage] of every attack made.
    def self.attack(action:, next_target:, advantage_against: ->(_target) { false })
      effect = EffectResolver.call(action:).first
      attacks = []

      [ action.actor.attacks_per_action.to_i, 1 ].max.times do
        target = next_target.call
        break if target.nil?

        advantage = advantage_against.call(target)
        result = EffectExecutor.call(effect:, actor: action.actor, target:, advantage:)
        yield target, result, advantage if block_given?
        attacks << [ target, result, advantage ]
      end

      attacks
    end
  end
end
