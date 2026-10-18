module Combat
  # Who fights in a simulation: CombatSimulatorService builds one per character sheet (a PlayerCharacter, the
  # Combatant's owner) when it starts. It owns what changes during the fight: the current HP, the spell slots
  # left and each limited feature's uses left. Everything else it reads from the sheet through the delegate
  # list below, the contract a future Monster has to meet; the sheet itself is never written.
  class Participant
    # What the combat pipeline reads of whoever fights: the simulator, TurnRecord, EffectResolver (the weapon),
    # EffectExecutor (attack, AC, save DC), RollContext and SavingThrow (level, proficiency, ability modifiers).
    delegate :id, :name, :level, :max_hit_points, :initiative, :armor_class,
             :damage_dice, :damage_type, :attacks_per_action, :weapon_attack_bonus, :weapon_damage_modifier, :critical_hit_threshold,
             :proficiency_bonus, :spellcasting_feature, :spell_save_dc, :spell_attack_bonus, :spells, :gambits,
             :passive_effect_payloads, :immune_to?, :resistant_to?, :vulnerable_to?,
             *AbilityScores::ABILITY_SCORE_COLUMNS.map { |ability| :"#{ability}_modifier" },
             to: :character

    attr_reader :character, :current_hit_points, :feature_book

    # hit_points: the HP it starts with (an experiment's), the sheet's maximum by default. Rolls the uses of
    # any feature whose uses_formula has dice (FeatureBook#initial_uses).
    def initialize(character, hit_points: nil)
      @character = character
      @current_hit_points = hit_points || character.max_hit_points
      @feature_book = FeatureBook.new(character)
      @uses = @feature_book.initial_uses
    end

    def dead? = current_hit_points <= 0

    # After the defenses: an immunity takes nothing, a resistance halves (rounded down), a vulnerability doubles.
    def take_damage(amount:, damage_type:)
      raise ArgumentError, "Amount must be a positive Integer" unless amount.is_a?(Integer) && amount.positive?
      return if immune_to?(damage_type:)

      amount /= 2 if resistant_to?(damage_type:)
      amount *= 2 if vulnerable_to?(damage_type:)
      @current_hit_points = [ current_hit_points - amount, 0 ].max
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

    # Runs the self-targeted heal and damage passives of the trigger ("turn_start", "turn_end") whose HP
    # conditions hold; returns their EffectExecutor results.
    def apply_turn_passives!(trigger:)
      passive_effect_payloads(trigger:).filter_map do |payload|
        next unless payload["kind"].in?(%w[heal damage]) && passive_conditions_met?(payload["conditions"])

        effect = EffectInstance.from_payload(payload)
        EffectExecutor.call(effect:, actor: self, target: self) if effect.target_type == "self"
      end
    end

    private

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
