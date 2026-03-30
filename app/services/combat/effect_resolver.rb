module Combat
  # Translates a CombatAction into an array of EffectInstances.
  #
  # For :class_feature actions, it looks up the ClassFeatureUnlock valid for
  # the actor's current level and reads its effect_payload.
  class EffectResolver
    def self.call(action:)
      new(action:).call
    end

    def initialize(action:)
      @action = action
    end

    def call
      case @action.source_type
      when :class_feature
        resolve_class_feature
      else
        raise ArgumentError, "Unsupported source_type: #{@action.source_type}"
      end
    end

    private

      def resolve_class_feature
        feature = ClassFeature.find(@action.source_id)
        actor   = @action.actor
        level   = actor.respond_to?(:level) ? actor.level : 1

        unlock = feature.class_feature_unlocks
                        .where("level <= ?", level)
                        .order(level: :desc)
                        .first

        raise "No unlock found for '#{feature.name}' at level #{level}" unless unlock
        raise "No effect_payload defined for '#{feature.name}' unlock at level #{unlock.level}" if unlock.effect_payload.blank?

        [ EffectInstance.from_payload(unlock.effect_payload) ]
      end
  end
end
