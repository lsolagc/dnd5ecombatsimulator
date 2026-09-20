module Combat
  # Represents a single atomic effect to be applied in combat.
  # Built from a ClassFeatureUnlock#effect_payload hash.
  #
  # Supported kinds: :heal, :damage
  #
  # effect_payload schema:
  #   {
  #     "kind"        => "heal" | "damage",
  #     "roll"        => "<roll expression>",   # e.g. "1d10 + actor_level"
  #     "target"      => "self" | "target",
  #     "damage_type" => "<type>",              # optional, for :damage kind
  #     "attack"      => "spell",               # optional, for :damage kind: the actor rolls a spell
  #                                             #   attack against the target's AC; a miss deals nothing
  #     "save"        => {                      # optional, for :heal / :damage kind
  #       "ability"    => "<ability name>",     #   e.g. "dexterity"
  #       "dc"         => <Integer> | "spell",  #   "spell" = the actor's spell save DC
  #       "on_success" => "half" | "negate"
  #     }
  #   }
  class EffectInstance
    ATTACK_TYPES = %w[spell].freeze

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
