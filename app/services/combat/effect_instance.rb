module Combat
  # Represents a single atomic effect to be applied in combat.
  # Built from an effect_payload hash (a ClassFeatureUnlock's, a Spell's, or the one
  # EffectResolver derives from the actor's equipped weapon for the Attack action).
  #
  # Supported kinds: :heal, :damage
  #
  # effect_payload schema:
  #   {
  #     "kind"        => "heal" | "damage",
  #     "roll"        => "<roll expression>",   # e.g. "1d10 + actor_level"
  #     "target"      => "self" | "enemy" | "ally",   # who may be chosen; enemy/ally are relative to the actor's party
  #     "damage_type" => "<type>",              # optional, for :damage kind
  #     "attack"      => "spell" | "weapon",    # optional, for :damage kind: the actor rolls an attack
  #                                             #   against the target's AC; a miss deals nothing. A weapon
  #                                             #   attack uses weapon_attack_bonus and the actor's critical
  #                                             #   hit threshold, a spell attack spell_attack_bonus and 20
  #     "save"        => {                      # optional, for :heal / :damage kind
  #       "ability"    => "<ability name>",     #   e.g. "dexterity"
  #       "dc"         => <Integer> | "spell",  #   "spell" = the actor's spell save DC
  #       "on_success" => "half" | "negate"
  #     }
  #   }
  class EffectInstance
    ATTACK_TYPES = %w[spell weapon].freeze

    attr_reader :kind, :roll_expression, :target_type, :damage_type, :save, :attack

    def initialize(kind:, roll_expression:, target_type:, damage_type: nil, save: nil, attack: nil)
      raise ArgumentError, "Unsupported attack type: #{attack.inspect}" unless attack.nil? || ATTACK_TYPES.include?(attack.to_s)

      @attack          = attack&.to_s
      @kind            = kind.to_sym
      @roll_expression = roll_expression
      @target_type     = target_type.to_s
      @damage_type     = damage_type
      @save            = save&.deep_stringify_keys
    end

    def self.from_payload(payload)
      new(
        kind:            payload.fetch("kind"),
        roll_expression: payload.fetch("roll"),
        target_type:     payload.fetch("target"),
        damage_type:     payload["damage_type"],
        save:            payload["save"],
        attack:          payload["attack"]
      )
    end
  end
end
