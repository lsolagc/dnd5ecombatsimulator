class CombatSimulatorService
  DEFAULT_MAX_ROUNDS = 20

  def initialize(party_one:, party_two:, seed: nil, max_rounds: DEFAULT_MAX_ROUNDS)
    raise ArgumentError, "Both parties must be Arrays" unless party_one.is_a?(Array) && party_two.is_a?(Array)
    raise ArgumentError, "Parties must not be empty" if party_one.empty? || party_two.empty?

    @party_one = party_one
    @party_two = party_two
    @seed = seed
    @max_rounds = Integer(max_rounds)
    raise ArgumentError, "max_rounds must be greater than 0" if @max_rounds <= 0

    @rng = @seed.nil? ? Random.new : Random.new(@seed)
    @round_log = []
    @uses_remaining = {}
    # Eldritch Strike pending marks: target.id => attacker.id, consumed by the first
    # saving throw the target rolls against a spell from that same attacker. No
    # turn/round tracking — see notes on the Eldritch Strike class feature (db/seeds.rb).
    @eldritch_strike_pending = {}
  end

  def call
    with_seed do
      initialize_state
      initiative_order = build_initiative_order

      round_number = 0

      while round_number < @max_rounds
        break if combat_over?

        round_number += 1
        turns = execute_round(round_number:, initiative_order:)
        @round_log << { round: round_number, turns: turns }
      end

      build_result(round_number:)
    end
  end

  private

    def with_seed
      return yield if @seed.nil?

      previous_seed = Random.srand(@seed)
      begin
        yield
      ensure
        Random.srand(previous_seed)
      end
    end

    def initialize_state
      all_combatants.each do |combatant|
        combatant.current_hit_points = combatant.max_hit_points if combatant.current_hit_points.nil?
      end

      all_combatants.each do |combatant|
        @uses_remaining[combatant.id] = resolve_initial_uses_for(combatant:)
      end
    end

    def resolve_initial_uses_for(combatant:)
      feature_uses = {}

      highest_unlock_per_feature(combatant:).each do |unlock|
        uses = resolve_uses_for_unlock(combatant:, unlock:)
        feature_uses[unlock.class_feature_id] = uses unless uses.nil?
      end

      feature_uses
    end

    def resolve_uses_for_unlock(combatant:, unlock:)
      return unlock.uses if unlock.uses.present?
      return nil if unlock.uses_formula.blank?

      context = Combat::RollContext.new(actor: combatant)
      outcome = Combat::RollExpression.new(expression: unlock.uses_formula).resolve(context:)
      normalize_uses_value(outcome.total)
    end

    def normalize_uses_value(value)
      value.to_f.floor
    end

    def build_initiative_order
      initiative_entries = all_combatants.each_with_index.map do |combatant, index|
        {
          combatant: combatant,
          initiative: Dice.d20(modifier: combatant.initiative).total,
          tie_breaker: index
        }
      end

      initiative_entries
        .sort_by { |entry| [ -entry[:initiative], entry[:tie_breaker] ] }
        .map { |entry| entry[:combatant] }
    end

    def execute_round(round_number:, initiative_order:)
      turns = []

      initiative_order.each_with_index do |actor, turn_index|
        next if actor.dead?
        break if combat_over?

        start_log = turn_passive_log(actor:, trigger: :turn_start, round_number:, turn_index: turn_index + 1)
        turns << start_log if start_log
        next if actor.dead?

        available = available_actions_for(actor:)
        unless available.empty?
          chosen_action = choose_turn_action(available:, actor:)
          turns << execute_action(actor:, chosen_action:, round_number:, turn_index: turn_index + 1)

          bonus_turn = war_magic_turn(actor:, chosen_action:, round_number:, turn_index: turn_index + 1)
          turns << bonus_turn if bonus_turn
        end

        extra_turn = action_surge_turn(actor:, round_number:, turn_index: turn_index + 1)
        turns << extra_turn if extra_turn

        end_log = turn_passive_log(actor:, trigger: :turn_end, round_number:, turn_index: turn_index + 1)
        turns << end_log if end_log
      end

      turns
    end

    # Action Surge: if the actor has an unused Action Surge, take one extra action right
    # after their normal action. Not recursive — the extra action never grants another one.
    def action_surge_turn(actor:, round_number:, turn_index:)
      unlock = action_surge_unlock_for(actor:)
      return nil unless unlock

      uses = @uses_remaining.dig(actor.id, unlock.class_feature_id)
      return nil unless uses.is_a?(Integer) && uses.positive?

      available = available_actions_for(actor:)
      return nil if available.empty?

      chosen_action = available.sample(random: @rng)
      consume_feature_use!(actor:, class_feature_id: unlock.class_feature_id)
      execute_action(actor:, chosen_action:, round_number:, turn_index:).merge(extra: true)
    end

    def action_surge_unlock_for(actor:)
      highest_unlock_per_feature(combatant: actor).find { |unlock| unlock.class_feature.name == "Action Surge" }
    end

    # War Magic / Improved War Magic: casting a spell as the turn's normal action grants
    # a bonus weapon attack right after it. Not recursive (a plain attack, via
    # execute_attack_action, never triggers another one) and never fired from the
    # Action Surge extra action — only from the turn's normal chosen_action.
    def war_magic_turn(actor:, chosen_action:, round_number:, turn_index:)
      return nil unless war_magic_available?(actor:, chosen_action:)

      execute_attack_action(actor:, round_number:, turn_index:).merge(bonus: true)
    end

    def war_magic_available?(actor:, chosen_action:)
      return false unless chosen_action[:type] == :cast_spell

      unlocks = highest_unlock_per_feature(combatant: actor)
      return true if unlocks.any? { |unlock| unlock.class_feature.name == "Improved War Magic" }

      unlocks.any? { |unlock| unlock.class_feature.name == "War Magic" } && chosen_action[:spell].cantrip?
    end

    def eldritch_strike_unlocked?(actor:)
      highest_unlock_per_feature(combatant: actor).any? { |unlock| unlock.class_feature.name == "Eldritch Strike" }
    end

    def turn_passive_log(actor:, trigger:, round_number:, turn_index:)
      results = trigger == :turn_start ? actor.apply_start_of_turn_passives! : actor.apply_end_of_turn_passives!
      return nil if results.empty?

      {
        round: round_number,
        turn: turn_index,
        actor_id: actor.id,
        actor_name: actor.name,
        actor_party: party_for(actor),
        action: { type: :turn_passive, trigger: trigger.to_s },
        results: serialize_effect_results(results:)
      }
    end

    def available_actions_for(actor:)
      actions = [ { type: :attack } ]
      combat_superiority_unlock = combat_superiority_unlock_for(actor:)

      highest_unlock_per_feature(combatant: actor).each do |unlock|
        next if unlock.effect_payload.blank?

        payload = unlock.effect_payload.deep_stringify_keys
        next unless payload["kind"].in?([ "heal", "damage" ])
        next if payload["trigger"].present?

        resource_feature_id = resource_class_feature_id(feature: unlock.class_feature, combat_superiority_unlock:)
        next if resource_feature_id == combat_superiority_unlock&.class_feature_id && !actor.known_maneuvers.exists?(id: unlock.class_feature_id)

        uses = @uses_remaining.dig(actor.id, resource_feature_id)
        next if uses.is_a?(Integer) && uses <= 0

        actions << {
          type: :class_feature,
          class_feature: unlock.class_feature,
          unlock: unlock,
          payload: payload,
          uses_remaining: uses
        }
      end

      actor.spells.each do |spell|
        next if spell.effect_payload.blank?
        next unless spell.cantrip? || actor.available_spell_slots[spell.level].to_i.positive?

        actions << { type: :cast_spell, spell: spell, payload: spell.effect_payload.deep_stringify_keys }
      end

      actions
    end

    # Deliberately primitive turn AI: a spellcaster with at least one castable spell
    # flips a coin between the "physical" branch (attack + class features, uniform)
    # and the "spell" branch (cast_spell options, uniform). Non-casters, or casters
    # with nothing castable right now, keep the original uniform sample over
    # everything — no coin flip — so @rng draws stay unchanged for the vast majority
    # of actors/tests.
    def choose_turn_action(available:, actor:)
      spell_options = available.select { |a| a[:type] == :cast_spell }
      if actor.spellcasting_feature.present? && spell_options.any?
        other_options = available - spell_options
        (@rng.rand < 0.5 ? other_options : spell_options).sample(random: @rng)
      else
        available.sample(random: @rng)
      end
    end

    def execute_action(actor:, chosen_action:, round_number:, turn_index:)
      case chosen_action[:type]
      when :attack
        execute_attack_action(actor:, round_number:, turn_index:)
      when :class_feature
        execute_class_feature_action(actor:, chosen_action:, round_number:, turn_index:)
      when :cast_spell
        execute_cast_spell_action(actor:, chosen_action:, round_number:, turn_index:)
      else
        raise ArgumentError, "Unsupported action type: #{chosen_action[:type]}"
      end
    end

    def execute_attack_action(actor:, round_number:, turn_index:)
      enemy_party = party_for(actor) == :party_one ? @party_two : @party_one
      attacks = []

      [ actor.attacks_per_action.to_i, 1 ].max.times do
        target = alive_combatants(enemy_party).sample(random: @rng)
        break if target.nil?

        attack_roll = actor.roll_an_attack
        attacked = target.get_attacked(attack_roll:)

        @eldritch_strike_pending[target.id] = actor.id if attacked[:success] && eldritch_strike_unlocked?(actor:)

        attacks << {
          kind: :attack,
          target_id: target.id,
          target_name: target.name,
          success: attacked[:success],
          damage: attacked[:success] ? attack_roll.damage : 0,
          attack_roll: {
            total: attack_roll.total,
            crit: attack_roll.crit,
            damage: attack_roll.damage
          },
          message: attacked[:message]
        }
      end

      {
        round: round_number,
        turn: turn_index,
        actor_id: actor.id,
        actor_name: actor.name,
        actor_party: party_for(actor),
        action: {
          type: :attack
        },
        results: attacks
      }
    end

    def execute_class_feature_action(actor:, chosen_action:, round_number:, turn_index:)
      feature = chosen_action[:class_feature]
      payload = chosen_action[:payload]
      target = resolve_feature_target(actor:, payload:)

      action = Combat::CombatAction.new(
        source_type: :class_feature,
        source_id: feature.id,
        actor: actor,
        targets: target.nil? ? [] : [ target ]
      )

      indomitable_unlock = target && indomitable_unlock_for(combatant: target)
      reroll_saving_throw = indomitable_unlock && indomitable_available?(combatant: target, unlock: indomitable_unlock)

      results = Combat::ActionRunner.call(action:, reroll_saving_throw: !!reroll_saving_throw)
      resource_feature_id = resource_class_feature_id(feature:, combat_superiority_unlock: combat_superiority_unlock_for(actor:))
      consume_feature_use!(actor:, class_feature_id: resource_feature_id)

      if reroll_saving_throw
        results.each do |result|
          next unless result.saving_throw&.rerolled

          consume_feature_use!(actor: target, class_feature_id: indomitable_unlock.class_feature_id)
        end
      end

      {
        round: round_number,
        turn: turn_index,
        actor_id: actor.id,
        actor_name: actor.name,
        actor_party: party_for(actor),
        action: {
          type: :class_feature,
          feature_id: feature.id,
          feature_slug: feature.slug,
          feature_name: feature.name,
          target_type: payload["target"]
        },
        results: serialize_effect_results(results:)
      }
    end

    def execute_cast_spell_action(actor:, chosen_action:, round_number:, turn_index:)
      spell = chosen_action[:spell]
      payload = chosen_action[:payload]
      target = resolve_feature_target(actor:, payload:)

      disadvantage_on_save = target && @eldritch_strike_pending[target.id] == actor.id
      @eldritch_strike_pending.delete(target.id) if disadvantage_on_save

      results = actor.cast_spell(slug: spell.slug, targets: [ target ].compact, disadvantage_on_save: !!disadvantage_on_save)

      {
        round: round_number,
        turn: turn_index,
        actor_id: actor.id,
        actor_name: actor.name,
        actor_party: party_for(actor),
        action: {
          type: :cast_spell,
          spell_id: spell.id,
          spell_slug: spell.slug,
          spell_name: spell.name,
          target_type: payload["target"]
        },
        results: serialize_effect_results(results:)
      }
    end

    def serialize_effect_results(results:)
      results.map do |result|
        {
          kind: result.kind,
          applied: result.applied,
          amount: result.amount,
          hp_before: result.hp_before,
          hp_after: result.hp_after,
          message: result.message,
          roll_outcome: {
            expression: result.roll_outcome.expression,
            resolved_expression: result.roll_outcome.resolved_expression,
            dice: result.roll_outcome.dice,
            rolls: result.roll_outcome.rolls,
            modifiers: result.roll_outcome.modifiers,
            total: result.roll_outcome.total
          }
        }
      end
    end

    def resolve_feature_target(actor:, payload:)
      return actor if payload["target"] == "self"

      # A target action can pick any alive combatant, including the actor.
      alive_combatants(all_combatants).sample(random: @rng)
    end

    def consume_feature_use!(actor:, class_feature_id:)
      uses = @uses_remaining.dig(actor.id, class_feature_id)
      return unless uses.is_a?(Integer)

      @uses_remaining[actor.id][class_feature_id] = [ uses - 1, 0 ].max
    end

    # A maneuver's "uses remaining" is tracked on the shared Combat Superiority pool
    # (identified by matching resource_name), not on the maneuver's own class_feature_id,
    # since maneuvers never carry their own uses.
    def resource_class_feature_id(feature:, combat_superiority_unlock:)
      return feature.id if combat_superiority_unlock.nil?
      return feature.id if feature.resource_name.blank?
      return feature.id unless feature.resource_name == combat_superiority_unlock.class_feature.resource_name

      combat_superiority_unlock.class_feature_id
    end

    def indomitable_unlock_for(combatant:)
      highest_unlock_per_feature(combatant:).find { |unlock| unlock.class_feature.name == "Indomitable" }
    end

    def indomitable_available?(combatant:, unlock:)
      uses = @uses_remaining.dig(combatant.id, unlock.class_feature_id)
      uses.is_a?(Integer) && uses.positive?
    end

    def combat_superiority_unlock_for(actor:)
      highest_unlock_per_feature(combatant: actor).find { |unlock| unlock.class_feature.name == "Combat Superiority" }
    end

    def highest_unlock_per_feature(combatant:)
      unlocks = ClassFeatureUnlock
                  .joins(:class_feature)
                  .includes(:class_feature)
                  .where(class_features: { player_class_id: combatant.player_class_id })
                  .where("class_feature_unlocks.level <= ?", combatant.level)
                  .select { |unlock| ClassFeature.visible_for?(unlock.class_feature, martial_archetype: combatant.martial_archetype, fighting_style: combatant.fighting_style) }

      unlocks
        .group_by(&:class_feature_id)
        .values
        .map { |group| group.max_by(&:level) }
    end

    def build_result(round_number:)
      party_one_alive = alive_combatants(@party_one).any?
      party_two_alive = alive_combatants(@party_two).any?

      draw = !party_one_alive && !party_two_alive
      winning_party = if draw
        nil
      elsif party_one_alive && !party_two_alive
        :party_one
      elsif party_two_alive && !party_one_alive
        :party_two
      else
        nil
      end

      outcome = if draw
        :draw
      elsif winning_party.nil? && round_number >= @max_rounds
        :max_rounds_reached
      else
        :victory
      end

      {
        winning_party: winning_party,
        total_rounds: round_number,
        round_log: @round_log,
        draw: draw,
        outcome: outcome
      }
    end

    def combat_over?
      alive_combatants(@party_one).empty? || alive_combatants(@party_two).empty?
    end

    def all_combatants
      @all_combatants ||= @party_one + @party_two
    end

    def alive_combatants(collection)
      collection.reject(&:dead?)
    end

    def party_for(combatant)
      @party_one.include?(combatant) ? :party_one : :party_two
    end
end
