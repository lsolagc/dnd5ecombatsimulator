class ClassFeatureUnlock < ApplicationRecord
  TARGETS = %w[self enemy ally].freeze
  # The PHB's costs of an activity in the turn's economy (declared only: the simulator does not charge them yet).
  ACTION_COSTS = %w[action bonus_action reaction].freeze
  # One status a maneuver applies to the target it hits (Distracting Strike), from Combat::Status's vocabulary.
  STATUS = { "kind" => Combat::Status::KINDS, "ends" => Combat::Status::ENDS }.freeze

  # Every effect a feature can declare in its effect_payload: kind => the fields it requires and the ones it
  # may carry, each with the values it accepts (nil: any value; an Array: one of them; a Class: an instance of
  # it; a Hash: a nested object with exactly those fields, all required; [ Hash ]: a list of such objects).
  # Any other field is refused.
  # Only heal and damage without a trigger are turn actions (ClassFeature#action_payload_at); a trigger makes a
  # passive (PlayerCharacter#passive_effect_payloads). The other kinds carry no trigger: Combat::FeatureBook and
  # PlayerCharacter#combat_superiority read them by kind.
  EFFECT_KINDS = {
    "heal" => {
      required: { "roll" => String, "target" => TARGETS },
      optional: { "trigger" => %w[turn_start turn_end], "conditions" => Hash, "save" => Hash }
    },
    "damage" => {
      required: { "roll" => String, "target" => TARGETS },
      optional: { "damage_type" => String, "attack" => %w[spell weapon], "save" => Hash, "applies_to" => %w[weapon_attack],
                  "statuses" => [ STATUS ], "trigger" => %w[turn_start turn_end], "conditions" => Hash }
    },
    # attack_bonus and armor_class: no feature declares them, the sheet holds the final values (Archery, Defense in).
    "modifier" => {
      required: { "modifier" => %w[attack_bonus armor_class damage_bonus critical_hit_threshold], "value" => Integer },
      optional: { "trigger" => %w[always], "target" => TARGETS }
    },
    # One more action on the turn (Action Surge); its uses are the unlock's.
    "extra_action" => { required: {} },
    # +count+ activities at +as+ cost once the turn's action casts a spell (War Magic: cantrip; Improved: any_spell).
    "grants_activity" => {
      required: { "activity" => %w[weapon_attack], "count" => (1..), "as" => ACTION_COSTS,
                  "after" => { "cast_with_action" => %w[cantrip any_spell] } }
    },
    # Rides along a hit (Eldritch Strike): the target's next save against the attacker's own spells has disadvantage.
    # Only the Status kind the engine applies on a hit (Combat::FeatureBook#rider): another one would validate and do nothing.
    "rider" => { required: { "event" => %w[weapon_hit], "applies" => Combat::Status::KINDS & %w[disadvantage_on_next_save], "against" => %w[own_spells] } },
    # Reroll a failed saving throw (Indomitable); its uses are the unlock's.
    "reroll_save" => { required: { "when" => %w[failed] } },
    # The pool whose uses every feature with the same resource_name spends (Combat Superiority's superiority dice).
    "resource_pool" => { required: {} }
  }.freeze

  belongs_to :class_feature

  enum :action_type, [ :passive, :action, :bonus_action, :reaction, :no_action, :special ], prefix: true
  enum :recharge_type, [ :none, :short_rest, :long_rest, :short_or_long_rest, :turn, :round, :special ], prefix: true

  validates :level, presence: true, inclusion: { in: 1..20 }
  validates :level, uniqueness: { scope: :class_feature_id }
  validates :uses, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :effect_payload_fits_its_kind, if: -> { effect_payload.present? }

  private

    def effect_payload_fits_its_kind
      payload = effect_payload.deep_stringify_keys
      spec = EFFECT_KINDS[payload["kind"]]
      return errors.add(:effect_payload, "has an unknown kind: #{payload['kind'].inspect}") if spec.nil?

      field_problems(payload.except("kind"), spec[:required], spec.fetch(:optional, {})).each { errors.add(:effect_payload, it) }
    end

    def field_problems(fields, required, optional, path = nil)
      name = ->(key) { [ path, key ].compact.join(".") }
      missing = (required.keys - fields.keys).map { "is missing #{name.(it)}" }
      unknown = (fields.keys - required.keys - optional.keys).map { "has an unknown field #{name.(it)}" }
      invalid = fields.flat_map { |key, value| value_problems(value, required.fetch(key) { optional[key] }, name.(key)) }
      missing + unknown + invalid
    end

    def value_problems(value, accepted, label)
      case accepted
      in [ Hash => item ]
        return [ "#{label} must be a list" ] unless value.is_a?(Array)

        value.each_with_index.flat_map { |element, index| value_problems(element, item, "#{label}[#{index}]") }
      in Hash then value.is_a?(Hash) ? field_problems(value.stringify_keys, accepted, {}, label) : [ "#{label} must be an object" ]
      in Array then accepted.include?(value) ? [] : [ "#{label} must be one of #{accepted.join(', ')}" ]
      in Class then value.is_a?(accepted) ? [] : [ "#{label} must be of type #{accepted.name.downcase}" ]
      in Range then value.is_a?(Integer) && accepted.cover?(value) ? [] : [ "#{label} must be an integer of at least #{accepted.begin}" ]
      else []
      end
    end
end
