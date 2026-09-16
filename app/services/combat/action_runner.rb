module Combat
  # Orchestrates the full pipeline: CombatAction → EffectResolver → EffectExecutor.
  #
  # Returns an array of EffectExecutor::Result, one per resolved EffectInstance.
  class ActionRunner
    def self.call(action:, reroll_saving_throw: false, disadvantage_on_save: false)
      effects = EffectResolver.call(action:)

      effects.map do |effect|
        target = effect.target_type == "self" ? action.actor : action.targets.first
        EffectExecutor.call(effect:, actor: action.actor, target:, reroll_saving_throw:, disadvantage_on_save:)
      end
    end
  end
end
