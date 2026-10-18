module Combat
  # What a combatant knows how to do in a simulation, read from its sheet: the features it has unlocked,
  # which of them it can choose as a turn action, the ones the simulator runs by rules of their own
  # (Action Surge, War Magic, Eldritch Strike, Indomitable; ClassFeature's predicates) and each feature's
  # uses at the start of combat. Read-only: the uses left are counted by CombatSimulatorService.
  # Delegates to the character's cached lookups (PlayerCharacter#feature_unlocks, #action_payload,
  # #combat_superiority); its only state is the known maneuvers, read once per book.
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

    # The Action Surge unlock, or nil.
    def action_surge
      unlocks.find { |unlock| unlock.class_feature.action_surge? }
    end

    # The Indomitable unlock, or nil.
    def indomitable
      unlocks.find { |unlock| unlock.class_feature.indomitable? }
    end

    # Whether casting +spell+ grants War Magic's bonus weapon attack: any spell with Improved War Magic,
    # only a cantrip with War Magic.
    def war_magic_for?(spell)
      features = unlocks.map(&:class_feature)
      return true if features.any?(&:improved_war_magic?)

      spell.cantrip? && features.any?(&:war_magic?)
    end

    def eldritch_strike?
      unlocks.any? { |unlock| unlock.class_feature.eldritch_strike? }
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

      def maneuver?(feature)
        feature.maneuver_of?(@character.combat_superiority)
      end

      def known_maneuver_ids
        @known_maneuver_ids ||= @character.known_maneuvers.pluck(:id).to_set
      end
  end
end
