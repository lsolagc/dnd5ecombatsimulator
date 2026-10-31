module Combat
  # One atomic combat effect, built from an effect_payload (a feature's, a spell's or the Attack action's weapon).
  # Payload keys: ClassFeatureUnlock::EFFECT_KINDS; their meaning: .okf/architecture/combat-effect-pipeline.md
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
