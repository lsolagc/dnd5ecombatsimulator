module Combat
  # The intent of a combatant to act on its turn (glossary: Action); its fields: .okf/architecture/combat-effect-pipeline.md (Contract)
  class CombatAction
    attr_reader :source_type, :source_id, :actor, :targets, :context

    def initialize(source_type:, source_id:, actor:, targets: [], context: {})
      @source_type = source_type.to_sym
      @source_id   = source_id
      @actor       = actor
      @targets     = Array(targets)
      @context     = context
    end
  end
end
