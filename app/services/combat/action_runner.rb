module Combat
  # Orchestrates the full pipeline: CombatAction → EffectResolver → EffectExecutor.
  #
  # Returns an array of EffectExecutor::Result, one per resolved EffectInstance.
  class ActionRunner
    def self.call(action:)
      effects = EffectResolver.call(action:)

      effects.map do |effect|
        target = effect.target_type == "self" ? action.actor : action.targets.first
        EffectExecutor.call(effect:, actor: action.actor, target:)
      end
    end
  end
end
