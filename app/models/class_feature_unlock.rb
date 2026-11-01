class ClassFeatureUnlock < ApplicationRecord
  include EffectPayloadValidation

  TARGETS = %w[self enemy ally].freeze
  # The PHB's costs of an activity in the turn's economy (declared only: the simulator does not charge them yet).
  ACTION_COSTS = %w[action bonus_action reaction].freeze
  # One status a maneuver applies to the target it hits (Distracting Strike), from Combat::Status's vocabulary.
  STATUS = { "kind" => Combat::Status::KINDS, "ends" => Combat::Status::ENDS }.freeze
  # A saving throw against the effect: dc a number or "spell" (the caster's spell save DC); on_success halves (rounded down) or negates.
  SAVE = { "ability" => AbilityScores::ABILITY_SCORE_COLUMNS, "dc" => [ 1..30, "spell" ], "on_success" => %w[half negate] }.freeze

  # Every effect_payload kind => its required and optional fields, each with the values it accepts, as EffectPayloadValidation#value_problems reads them.
  # See .okf/models/class-feature-unlock.md (Effect vocabulary)
  EFFECT_KINDS = {
    "heal" => {
      required: { "roll" => String, "target" => TARGETS },
      optional: { "trigger" => %w[turn_start turn_end], "conditions" => Hash, "save" => SAVE }
    },
    "damage" => {
      required: { "roll" => String, "target" => TARGETS },
      optional: { "damage_type" => String, "attack" => %w[spell weapon], "save" => SAVE, "applies_to" => %w[weapon_attack],
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
end
