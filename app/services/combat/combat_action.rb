module Combat
  # Represents the intent of a combatant to perform an action on their turn.
  #
  # source_type: :class_feature | :spell | :weapon_attack
  # source_id:   ID of the ClassFeature (or future Spell) record
  # actor:       The combatant using the action
  # targets:     Array of target combatants (may be empty for self-targeting actions)
  # context:     Hash of extra info (e.g. upcast level, ability mode)
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
