module Combat
  # Runs the pipeline, CombatAction → EffectResolver → EffectExecutor: one EffectExecutor::Result per EffectInstance.
  class ActionRunner
    def self.call(action:, reroll_saving_throw: false, disadvantage_on_save: false, crit: false)
      effects = EffectResolver.call(action:)

      effects.map do |effect|
        target = effect.target_type == "self" ? action.actor : action.targets.first
        EffectExecutor.call(effect:, actor: action.actor, target:, reroll_saving_throw:, disadvantage_on_save:, crit:)
      end
    end

    # The Attack action: up to +attacks+ weapon attacks, each at next_target's pick (nil ends it), yielding and returning
    # each [target, result, advantage]. See .okf/architecture/combat-effect-pipeline.md (Contract)
    def self.attack(action:, next_target:, advantage_against: ->(_target) { false }, attacks: action.actor.attacks_per_action)
      effect = EffectResolver.call(action:).first
      made = []

      [ attacks.to_i, 1 ].max.times do
        target = next_target.call
        break if target.nil?

        advantage = advantage_against.call(target)
        result = EffectExecutor.call(effect:, actor: action.actor, target:, advantage:)
        yield target, result, advantage if block_given?
        made << [ target, result, advantage ]
      end

      made
    end
  end
end
