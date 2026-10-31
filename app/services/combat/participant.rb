module Combat
  # Who fights in a simulation: Combat::Simulator builds one per character sheet (a PlayerCharacter, the
  # Combatant's owner) when it starts. It owns what changes during the fight: the current HP, the spell slots
  # left, each limited feature's uses left and the statuses it carries (Combat::Status). Everything else it reads from the sheet through the delegate
  # list below, the contract a future Monster has to meet; the sheet itself is never written.
  class Participant
    # What the combat pipeline reads of whoever fights: the simulator, TurnRecord, EffectResolver (the weapon),
    # EffectExecutor (attack, AC, save DC), RollContext and SavingThrow (level, proficiency, ability modifiers).
    delegate :name, :level, :max_hit_points, :initiative, :armor_class,
             :damage_dice, :damage_type, :attacks_per_action, :weapon_attack_bonus, :weapon_damage_modifier, :critical_hit_threshold,
             :proficiency_bonus, :spellcasting_feature, :spell_save_dc, :spell_attack_bonus, :spells, :gambits,
             :passive_effect_payloads, :defenses,
             *AbilityScores::ABILITY_SCORE_COLUMNS.map { |ability| :"#{ability}_modifier" },
             to: :character

    attr_reader :character, :current_hit_points, :feature_book, :statuses

    # The Combatant's id, not the sheet's: a PlayerCharacter and a Monster can share an id. The log's
    # actor_id/target_id and the keys of Combat::Simulator's hit_points:/gambits: are this id.
    def id = character.combatant.id

    # hit_points: the HP it starts with (an experiment's), the sheet's maximum by default. Rolls the uses of
    # any feature whose uses_formula has dice (FeatureBook#initial_uses).
    def initialize(character, hit_points: nil)
      @character = character
      @current_hit_points = hit_points || character.max_hit_points
      @feature_book = FeatureBook.new(character)
      @uses = @feature_book.initial_uses
      @statuses = []
    end

    def dead? = current_hit_points <= 0

    # After the defenses: an immunity takes nothing, a resistance halves (rounded down), a vulnerability doubles.
    def take_damage(amount:, damage_type:)
      raise ArgumentError, "Amount must be a positive Integer" unless amount.is_a?(Integer) && amount.positive?

      @current_hit_points = [ current_hit_points - defenses.apply(amount, damage_type), 0 ].max
    end

    # Never past the maximum (from above it, healing brings it down to it).
    def heal(amount)
      @current_hit_points = [ current_hit_points + amount, max_hit_points ].min
    end

    # { spell level => slots left }, starting from the sheet's (PlayerCharacter#spell_slots).
    def available_spell_slots
      @available_spell_slots ||= character.spell_slots
    end

    # Spends a slot of the spell's level (none for a cantrip) and runs its effect.
    def cast_spell(spell, targets: [], disadvantage_on_save: false)
      spend_spell_slot!(spell.level) if spell.level.positive?

      ActionRunner.call(action: CombatAction.new(source_type: :spell, source_id: spell.id, actor: self, targets:), disadvantage_on_save:)
    end

    # Uses left of a limited feature, nil when unlimited.
    def uses_left(class_feature_id)
      @uses[class_feature_id]
    end

    def spend_use!(class_feature_id)
      uses = @uses[class_feature_id]
      @uses[class_feature_id] = [ uses - 1, 0 ].max if uses
    end

    # What it can do with its action right now, as Combat::ActionOptions: the Attack action (always), each
    # unlocked action feature with a use left (a maneuver it knows included) and each spell it can cast (a
    # cantrip, or with a slot of its level left). In that order: a seed's random pick depends on it.
    def action_options
      options = [ ActionOption.new(type: :attack) ]

      feature_book.unlocks.each do |unlock|
        feature = unlock.class_feature
        payload = feature_book.action_payload(feature)
        next unless payload

        uses = uses_left(feature_book.resource_feature_id(feature))
        next if uses.is_a?(Integer) && uses <= 0

        options << ActionOption.new(type: :class_feature, class_feature: feature, payload:, uses_remaining: uses)
      end

      spells.each do |spell|
        next if spell.effect_payload.blank?
        next unless spell.cantrip? || available_spell_slots[spell.level].to_i.positive?

        options << ActionOption.new(type: :cast_spell, spell:, payload: spell.effect_payload.deep_stringify_keys)
      end

      options
    end

    # Action Surge as an option (Combat::GambitPolicy's gambit action, Combat::TurnExecutor's random surge):
    # unlocked and with a use left, else nil.
    def action_surge_option
      unlock = feature_book.unlock_with("extra_action")
      uses = unlock && uses_left(unlock.class_feature_id)
      ActionOption.new(type: :action_surge, class_feature: unlock.class_feature, uses_remaining: uses) if uses.is_a?(Integer) && uses.positive?
    end

    # Runs the self-targeted heal and damage passives of the trigger ("turn_start", "turn_end") whose HP
    # conditions hold; returns their EffectExecutor results.
    def apply_turn_passives!(trigger:)
      passive_effect_payloads(trigger:).filter_map do |payload|
        next unless payload["kind"].in?(%w[heal damage]) && passive_conditions_met?(payload["conditions"])

        effect = EffectInstance.from_payload(payload)
        EffectExecutor.call(effect:, actor: self, target: self) if effect.target_type == "self"
      end
    end

    # At most one status per kind and source: applied again by the same source, it renews (replaces) the old one.
    def add_status(status)
      statuses.reject! { |held| held.kind == status.kind && held.source.equal?(status.source) }
      statuses << status
    end

    # Removes and returns every status of the kind (not_from: applied by anyone but that participant; from: by
    # that one only).
    def take_statuses(kind, not_from: nil, from: nil)
      return [] if statuses.empty?

      taken, @statuses = statuses.partition { |status| status_matches?(status, kind, not_from:, from:) }
      taken
    end

    def status?(kind, not_from: nil, from: nil)
      statuses.any? { |status| status_matches?(status, kind, not_from:, from:) }
    end

    # The source's turn starts: the statuses it applied that end then go.
    def expire_statuses!(source:)
      statuses.reject! { |status| status.ends == "source_turn_start" && status.source.equal?(source) }
    end

    private

      def status_matches?(status, kind, not_from:, from:)
        status.kind == kind && !(not_from && status.source.equal?(not_from)) && (from.nil? || status.source.equal?(from))
      end

      def spend_spell_slot!(spell_level)
        remaining = available_spell_slots[spell_level].to_i
        raise "No level #{spell_level} spell slots remaining for #{name}" if remaining <= 0

        available_spell_slots[spell_level] = remaining - 1
      end

      def passive_conditions_met?(conditions)
        cond = (conditions || {}).deep_stringify_keys
        hp = current_hit_points

        return false if cond.key?("current_hp_gt") && !(hp > cond["current_hp_gt"].to_i)
        return false if cond.key?("current_hp_gte") && !(hp >= cond["current_hp_gte"].to_i)
        return false if cond.key?("current_hp_lt") && !(hp < cond["current_hp_lt"].to_i)
        return false if cond.key?("current_hp_lte") && !(hp <= cond["current_hp_lte"].to_i)

        !cond.key?("current_hp_lte_max_hp_fraction") || hp <= max_hit_points.to_i * cond["current_hp_lte_max_hp_fraction"].to_f
      end
  end
end
