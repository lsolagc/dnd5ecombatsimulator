module Combat
  class RollContext
    attr_reader :actor, :target

    def initialize(actor:, target: nil)
      @actor = actor
      @target = target
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
