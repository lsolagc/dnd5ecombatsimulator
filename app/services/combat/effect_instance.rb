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
  #     "save"        => nil                    # reserved for future saving throws
  #   }
  class EffectInstance
    attr_reader :kind, :roll_expression, :target_type, :damage_type, :save

    def initialize(kind:, roll_expression:, target_type:, damage_type: nil, save: nil)
      @kind            = kind.to_sym
      @roll_expression = roll_expression
      @target_type     = target_type.to_s
      @damage_type     = damage_type
      @save            = save
    end

    def self.from_payload(payload)
      new(
        kind:            payload.fetch("kind"),
        roll_expression: payload.fetch("roll"),
        target_type:     payload.fetch("target"),
        damage_type:     payload["damage_type"],
        save:            payload["save"]
      )
    end
  end
end
