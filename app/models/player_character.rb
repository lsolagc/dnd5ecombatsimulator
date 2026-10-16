class PlayerCharacter < ApplicationRecord
  include AbilityScores
  include CombatantBehavior

  belongs_to :player_class
  belongs_to :martial_archetype, class_name: "ClassFeature", optional: true
  belongs_to :fighting_style, class_name: "ClassFeature", optional: true
  delegate :hit_die, :spellcasting_modifier, to: :player_class

  validate :martial_archetype_matches_player_class
  validate :fighting_style_matches_player_class

  has_one :combatant, as: :combatable, touch: true
  behave_as_combatant
  delegate_ability_scores_to :combatant
  accepts_nested_attributes_for :combatant

  has_many :player_character_spells, dependent: :destroy
  # In the order they were learned: the simulator's random picks follow it, so the same seed replays.
  has_many :spells, -> { order("player_character_spells.id") }, through: :player_character_spells

  has_many :player_character_maneuvers, dependent: :destroy
  has_many :known_maneuvers, through: :player_character_maneuvers, source: :maneuver

  has_many :gambits, -> { order(:position) }, as: :owner, dependent: :destroy

  MAX_HIT_POINTS_INPUT_CEILING = 2_147_483_647

  attr_accessor :max_hit_points_input
  attr_writer :available_spell_slots

  validates :max_hit_points_input, numericality: {
    only_integer: true,
    greater_than: 0,
    less_than_or_equal_to: MAX_HIT_POINTS_INPUT_CEILING
  }, allow_blank: true

  before_create :initialize_combatant, if: -> { combatant.nil? }
  before_create :setup_hit_points
  before_update :apply_hit_points_override, if: -> { max_hit_points_input.present? }

  def setup_hit_points
    return apply_hit_points_override if max_hit_points_input.present?

    self.max_hit_points = full_hit_points
  end

  def apply_hit_points_override
    self.max_hit_points = max_hit_points_input.to_i
  end

  # Full HP for the character's level: the hit die's maximum + CON modifier at every level.
  def full_hit_points
    hit_points_at_level_one + (level - 1) * (hit_die_value + constitution_modifier)
  end

  def hit_points_at_level_one
    hit_die_value + constitution_modifier
  end

  def hit_die_value
    hit_die.to_s.delete("d").to_i
  end

  # To-hit bonus of the equipped weapon, with passive bonuses (e.g. Fighting Style: Archery).
  def weapon_attack_bonus
    attack_bonus + modifier_bonus("attack_bonus")
  end

  # Flat damage added to the weapon's dice: STR modifier plus passive bonuses (e.g. Fighting Style: Dueling).
  def weapon_damage_modifier
    strength_modifier + modifier_bonus("damage_bonus")
  end

  def armor_class
    combatant.armor_class + modifier_bonus("armor_class")
  end

  def critical_hit_threshold
    thresholds = passive_effect_payloads(trigger: "always")
      .select { |payload| payload["kind"] == "modifier" && payload["modifier"] == "critical_hit_threshold" }
      .map { |payload| payload["value"].to_i }
      .select { |value| value.between?(1, 20) }

    thresholds.min || 20
  end

  def apply_start_of_turn_passives!
    apply_turn_passives!(trigger: "turn_start")
  end

  def apply_end_of_turn_passives!
    apply_turn_passives!(trigger: "turn_end")
  end

  # One payload per unlocked feature, the one in force at the character's level (ClassFeature#effect_payload_at).
  def passive_effect_payloads(trigger:)
    feature_unlocks.filter_map do |unlock|
      feature = unlock.class_feature
      payload = feature.effect_payload_at(level)
      next unless payload && payload["trigger"] == trigger

      payload.merge("feature_slug" => feature.slug, "feature_name" => feature.name)
    end
  end

  # The highest unlock at or below the character's level of every feature the character can see
  # (ClassFeature.visible_for?), each feature's unlocks loaded. In a fixed order, by the id of the
  # feature's first unlock at or below the level, since the simulator's random picks follow it.
  def feature_unlocks
    cached(:feature_unlocks, [ player_class_id, level, martial_archetype_id, fighting_style_id ]) do
      ClassFeature.where(player_class_id:).eager_load(:class_feature_unlocks).order("class_feature_unlocks.id")
        .select { |feature| ClassFeature.visible_for?(feature, martial_archetype:, fighting_style:) }
        .filter_map { |feature| feature.class_feature_unlocks.select { |unlock| unlock.level <= level }.presence }
        .sort_by { |unlocks| unlocks.first.id }
        .map { |unlocks| unlocks.max_by(&:level) }
    end
  end

  # The superiority-dice feature (ClassFeature#combat_superiority?) if unlocked: its uses pay for every maneuver.
  def combat_superiority
    feature_unlocks.map(&:class_feature).find(&:combat_superiority?)
  end

  def take_damage(amount:, damage_type:)
    raise ArgumentError, "Amount must be a positive Integer" unless amount.is_a?(Integer) && amount.positive?
    return if immune_to?(damage_type:)

    if resistant_to?(damage_type:)
      amount = amount / 2
    end

    if vulnerable_to?(damage_type:)
      amount = amount * 2
    end

    self.current_hit_points -= amount

    if current_hit_points <= 0
      self.current_hit_points = 0
    end
  end

  def initialize_combatant
    self.combatant = Combatant.new(combatable: self)
  end

  def class_progression
    cached(:class_progression, [ player_class_id, level ]) { player_class.progression_at(level) }
  end

  def proficiency_bonus
    class_progression&.proficiency_bonus || 2
  end

  def attacks_per_action
    class_progression&.attacks_per_action || 1
  end

  def spellcasting_feature
    cached(:spellcasting_feature, [ player_class_id, martial_archetype_id, fighting_style_id ]) do
      feature = player_class.class_features.find_by(grants_spellcasting: true)
      feature if feature && ClassFeature.visible_for?(feature, martial_archetype: martial_archetype, fighting_style: fighting_style)
    end
  end

  def reload(*)
    @lookup_cache = nil
    super
  end

  # Ability name ("intelligence"...) this character casts with: the chosen subclass's spellcasting
  # feature wins over the class's, so an Eldritch Knight gets INT although Fighter has none.
  def spellcasting_ability
    spellcasting_feature&.spellcasting_ability || spellcasting_modifier
  end

  def spellcasting_ability_modifier
    ability = spellcasting_ability or raise "#{name} has no spellcasting ability"

    public_send("#{ability}_modifier")
  end

  def spell_save_dc
    8 + proficiency_bonus + spellcasting_ability_modifier
  end

  def spell_attack_bonus
    proficiency_bonus + spellcasting_ability_modifier
  end

  def available_spell_slots
    @available_spell_slots ||= build_available_spell_slots
  end

  def cast_spell(slug:, targets: [], disadvantage_on_save: false)
    spell = spells.find_by!(slug: slug)
    consume_spell_slot!(spell.level) if spell.level.positive?

    action = Combat::CombatAction.new(
      source_type: :spell,
      source_id:   spell.id,
      actor:       self,
      targets:     targets
    )
    Combat::ActionRunner.call(action: action, disadvantage_on_save:)
  end

  # The turn actions a gambit of this character can choose, as [label, value] select options (value as in
  # Gambit#action_choice): Ataque, unlocked features the simulator runs as an action at the character's level
  # (ClassFeature#action_payload_at, Action Surge included) by first unlock level, maneuvers only when known,
  # and known spells with an effect by level.
  def gambit_action_options
    known_maneuver_ids = known_maneuvers.ids
    features = feature_unlocks.map(&:class_feature)
      .reject { |feature| feature.maneuver_of?(combat_superiority) && !known_maneuver_ids.include?(feature.id) }
      .sort_by { |feature| [ feature.class_feature_unlocks.map(&:level).min, feature.name ] }

    choices = [ Gambit.new(action_kind: :attack) ] +
      features.map { |feature| Gambit.new(action_kind: :class_feature, class_feature: feature) }
              .select { |gambit| gambit.action_surge? || gambit.class_feature.action_payload_at(level) } +
      spells.select { |spell| spell.effect_payload.present? }.sort_by { |spell| [ spell.level, spell.name ] }.map { |spell| Gambit.new(action_kind: :spell, spell:) }
    choices.map { |gambit| [ gambit.action_label, gambit.action_choice ] }
  end

  private

    def build_available_spell_slots
      feature = spellcasting_feature
      return {} unless feature

      progression = feature.spell_slot_progressions
                            .where("level <= ?", level)
                            .order(level: :desc)
                            .first

      progression ? progression.slots_by_level : {}
    end

    def consume_spell_slot!(spell_level)
      remaining = available_spell_slots[spell_level].to_i
      raise "No level #{spell_level} spell slots remaining for #{name}" if remaining <= 0

      available_spell_slots[spell_level] = remaining - 1
    end

    # Per-instance cache for lookups that depend only on the character's class, level and choices. The combat
    # loop asks for them on every attack; a changed key (say, a level edited on this instance) recomputes, and
    # #reload clears it.
    def cached(name, key)
      entry = (@lookup_cache ||= {})[name]
      return entry.last if entry&.first == key

      yield.tap { |value| @lookup_cache[name] = [ key, value ] }
    end

    def modifier_bonus(name)
      passive_effect_payloads(trigger: "always")
        .select { |payload| payload["kind"] == "modifier" && payload["modifier"] == name }
        .sum { |payload| payload["value"].to_i }
    end

    def martial_archetype_matches_player_class
      return unless martial_archetype

      errors.add(:martial_archetype, "must be a subclass-type class feature") unless martial_archetype.feature_type_subclass?

      if martial_archetype.player_class_id != player_class_id
        errors.add(:martial_archetype, "must belong to the character's class")
      end
    end

    def fighting_style_matches_player_class
      return unless fighting_style

      errors.add(:fighting_style, "must be an optional-type class feature") unless fighting_style.feature_type_optional?

      if fighting_style.player_class_id != player_class_id
        errors.add(:fighting_style, "must belong to the character's class")
      end
    end

    def apply_turn_passives!(trigger:)
      passive_effect_payloads(trigger:).filter_map do |payload|
        next unless passive_payload_actionable?(payload)
        next unless passive_conditions_met?(payload["conditions"])

        apply_passive_effect_payload(payload)
      end
    end

    def passive_payload_actionable?(payload)
      payload["kind"].in?([ "heal", "damage" ])
    end

    def apply_passive_effect_payload(payload)
      effect = Combat::EffectInstance.from_payload(payload)
      return nil unless effect.target_type == "self"

      Combat::EffectExecutor.call(effect:, actor: self, target: self)
    end

    def passive_conditions_met?(conditions)
      cond = (conditions || {}).deep_stringify_keys

      current_hp = current_hit_points.to_i
      max_hp = max_hit_points.to_i

      return false if cond.key?("current_hp_gt") && !(current_hp > cond["current_hp_gt"].to_i)
      return false if cond.key?("current_hp_gte") && !(current_hp >= cond["current_hp_gte"].to_i)
      return false if cond.key?("current_hp_lt") && !(current_hp < cond["current_hp_lt"].to_i)
      return false if cond.key?("current_hp_lte") && !(current_hp <= cond["current_hp_lte"].to_i)

      if cond.key?("current_hp_lte_max_hp_fraction")
        threshold = max_hp * cond["current_hp_lte_max_hp_fraction"].to_f
        return false unless current_hp <= threshold
      end

      true
    end
end
