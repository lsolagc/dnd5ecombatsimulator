module Combat
  class RollContext
    attr_reader :actor, :target, :combat_state

    def initialize(actor:, target: nil, combat_state: {})
      @actor = actor
      @target = target
      @combat_state = combat_state
    end

    def resolve(variable)
      case variable
      when /\A[a-z_]+_level\z/
        # Any *_level resolves to actor's level (single-class assumption)
        actor.respond_to?(:level) ? actor.level : 1
      when /\A([a-z]+)_modifier\z/
        ability = $1
        actor.respond_to?("#{ability}_modifier") ? actor.public_send("#{ability}_modifier") : 0
      when "proficiency_bonus"
        actor.respond_to?(:proficiency_bonus) ? actor.proficiency_bonus : 2
      when "level", "actor_level"
        actor.respond_to?(:level) ? actor.level : 1
      else
        0
      end
    end
  end
end
