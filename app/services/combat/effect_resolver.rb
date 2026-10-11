module Combat
  # Translates a CombatAction into an array of EffectInstances.
  #
  # For :class_feature actions, it looks up the ClassFeatureUnlock valid for
  # the actor's current level and reads its effect_payload.
  #
  # For :spell actions, it reads the effect_payload directly off the Spell
  # record (no per-level scaling/upcasting support yet).
  #
  # For :attack actions (the Attack action every combatant has), it derives the
  # payload from the actor's equipped weapon: a weapon attack that deals the
  # weapon's dice plus weapon_damage_modifier, of the weapon's damage type.
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
      when :spell
        resolve_spell
      when :attack
        resolve_attack
      else
        raise ArgumentError, "Unsupported source_type: #{@action.source_type}"
      end
    end

    private

      def resolve_attack
        actor = @action.actor
        modifier = actor.weapon_damage_modifier
        # RollExpression would read a malformed die ("oops") as an unknown variable worth 0, so a broken
        # weapon would silently deal no damage.
        unless RollExpression::DICE_PATTERN.match?(actor.damage_dice.to_s)
          raise ArgumentError, "dice must be formatted like [number of dice]d[type of die] (e.g. 4d8), got #{actor.damage_dice.inspect}"
        end

        [ EffectInstance.from_payload(
          "kind"        => "damage",
          "roll"        => "#{actor.damage_dice} #{modifier.negative? ? "-" : "+"} #{modifier.abs}",
          "target"      => "enemy",
          "damage_type" => actor.damage_type,
          "attack"      => "weapon"
        ) ]
      end

      def resolve_spell
        spell = Spell.find(@action.source_id)

        raise "No effect_payload defined for spell '#{spell.name}'" if spell.effect_payload.blank?

        [ EffectInstance.from_payload(spell.effect_payload) ]
      end

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
