module Combat
  # What a combatant knows how to do, read-only (glossary: Feature book): .okf/architecture/combat-simulator.md (Feature book)
  class FeatureBook
    def initialize(character)
      @character = character
    end

    # The highest unlock at or below the character's level of every feature it has (PlayerCharacter#feature_unlocks).
    def unlocks
      @character.feature_unlocks
    end

    # The feature's effect if the character can choose it as a turn action (PlayerCharacter#action_payload).
    # Nil when it cannot: not unlocked, no action effect at its level, or a maneuver it has not learned.
    def action_payload(feature)
      payload = @character.action_payload(feature)
      payload if payload && (!maneuver?(feature) || known_maneuver_ids.include?(feature.id))
    end

    # The unlock of the feature whose effect at the character's level is of +kind+, or nil: the simulator runs
    # "extra_action" (Action Surge) and "reroll_save" (Indomitable) by rules of their own, spending the unlock's uses.
    def unlock_with(kind)
      unlocks.find { |unlock| effects[unlock.class_feature_id]&.dig("kind") == kind }
    end

    # How many weapon attacks casting +spell+ as the turn's action grants (a grants_activity, War Magic), or nil:
    # after cast_with_action any_spell, any spell; after cantrip, only a cantrip. The most, if several apply.
    def weapon_attacks_after(spell)
      effects.each_value.filter_map do |payload|
        next unless payload && payload["kind"] == "grants_activity" && payload["activity"] == "weapon_attack"

        payload["count"] if payload.dig("after", "cast_with_action") == "any_spell" || (spell.cantrip? && payload.dig("after", "cast_with_action") == "cantrip")
      end.max
    end

    # The feature that rides +applies+ along every +event+ (Eldritch Strike: disadvantage_on_next_save on weapon_hit), or nil.
    def rider(event:, applies:)
      unlocks.find do |unlock|
        payload = effects[unlock.class_feature_id]
        payload && payload["kind"] == "rider" && payload["event"] == event && payload["applies"] == applies
      end&.class_feature
    end

    # The feature whose uses +feature+ spends: a maneuver (ClassFeature#maneuver_of?) spends the shared
    # superiority-dice pool, since maneuvers never carry uses of their own; anything else its own.
    def resource_feature_id(feature)
      maneuver?(feature) ? @character.combat_superiority.id : feature.id
    end

    # { class_feature_id => uses } at the start of combat, for features with limited uses: the unlock's
    # fixed uses, else its uses_formula (Combat::RollExpression, floored). A formula with dice rolls them.
    def initial_uses
      unlocks.each_with_object({}) do |unlock, uses|
        value = initial_uses_of(unlock)
        uses[unlock.class_feature_id] = value unless value.nil?
      end
    end

    private

      def initial_uses_of(unlock)
        return unlock.uses if unlock.uses.present?
        return if unlock.uses_formula.blank?

        Combat::RollExpression.new(expression: unlock.uses_formula).resolve(context: Combat::RollContext.new(actor: @character)).total.to_f.floor
      end

      def effects
        @character.effect_payloads
      end

      def maneuver?(feature)
        feature.maneuver_of?(@character.combat_superiority)
      end

      def known_maneuver_ids
        @known_maneuver_ids ||= @character.known_maneuvers.pluck(:id).to_set
      end
  end
end
