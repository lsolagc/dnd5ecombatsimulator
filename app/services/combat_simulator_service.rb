class CombatSimulatorService
  DEFAULT_MAX_ROUNDS = 20

  # Raised from #call when abort_if returns true; the partial simulation is discarded.
  class Aborted < StandardError; end

  # The `gambit` of a decision entry when no rule drove it: a random pick, or a gambit-driven actor
  # whose rules all failed.
  RANDOM_GAMBIT = "aleatório"
  IDLE_GAMBIT = "nenhum aplicável: parado"

  # abort_if: optional callable checked before every round (e.g. a batch cancelled from the UI).
  # gambits: optional copy of the rules, { character id (string) => [Gambit#snapshot, ...] } (a batch's
  # gambit_settings); the simulation runs and logs from it instead of each combatant's own gambits.
  def initialize(party_one:, party_two:, seed: nil, max_rounds: DEFAULT_MAX_ROUNDS, abort_if: nil, gambits: nil)
    raise ArgumentError, "Both parties must be Arrays" unless party_one.is_a?(Array) && party_two.is_a?(Array)
    raise ArgumentError, "Parties must not be empty" if party_one.empty? || party_two.empty?

    @party_one = party_one
    @party_two = party_two
    @seed = seed
    @abort_if = abort_if
    @gambit_settings = gambits
    @gambit_labels = {}.compare_by_identity
    @max_rounds = Integer(max_rounds)
    raise ArgumentError, "max_rounds must be greater than 0" if @max_rounds <= 0

    @rng = @seed.nil? ? Random.new : Random.new(@seed)
    @round_log = []
    @uses_remaining = {}
    # Eldritch Strike pending marks (a disadvantage_on_next_save rider): target.id => attacker.id, consumed by the first
    # saving throw the target rolls against a spell from that same attacker. No
    # turn/round tracking — see notes on the Eldritch Strike class feature (db/seeds.rb).
    @eldritch_strike_pending = {}
    # Distracting Strike marks: target.id => ids of the combatants who marked it. The first weapon attack
    # against the target by anyone else rolls with advantage and uses one mark up; a mark also
    # expires at the start of its owner's next turn (see execute_round).
    @advantage_marks = Hash.new { |marks, target_id| marks[target_id] = [] }
  end

  def call
    with_seed do
      initialize_state
      initiative_order = @initiative_order = build_initiative_order

      round_number = 0

      while round_number < @max_rounds
        break if combat_over?
        raise Aborted if @abort_if&.call

        round_number += 1
        turns = execute_round(round_number:, initiative_order:)
        @round_log << { round: round_number, turns: turns.map(&:to_h) }
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

      @feature_books = all_combatants.to_h { |combatant| [ combatant.id, Combat::FeatureBook.new(combatant) ] }
      all_combatants.each do |combatant|
        @uses_remaining[combatant.id] = feature_book(combatant).initial_uses
      end
    end

    # What the combatant knows how to do this simulation (built in initialize_state).
    def feature_book(combatant)
      @feature_books.fetch(combatant.id)
    end

    # One d20 per combatant, in party order (the RNG sequence), sorted by total with ties kept in that
    # order. The rolls stay in @initiative for the result.
    def build_initiative_order
      initiative_entries = all_combatants.each_with_index.map do |combatant, index|
        roll = Dice.d20(modifier: combatant.initiative)
        { combatant:, natural: roll.natural, total: roll.total, tie_breaker: index }
      end

      @initiative = initiative_entries.sort_by { |entry| [ -entry[:total], entry[:tie_breaker] ] }
      @initiative.map { |entry| entry[:combatant] }
    end

    def execute_round(round_number:, initiative_order:)
      turns = []

      initiative_order.each_with_index do |actor, turn_index|
        @advantage_marks.each_value { |sources| sources.delete(actor.id) }
        next if actor.dead?
        break if combat_over?

        start_log = turn_passive_log(actor:, trigger: :turn_start, round_number:, turn_index: turn_index + 1)
        turns << start_log if start_log
        next if actor.dead?

        gambits = enabled_gambits(actor:)
        if gambits.any?
          turns.concat(gambit_turns(actor:, gambits:, round_number:, turn_index: turn_index + 1))
        else
          available = available_actions_for(actor:)
          if available.any?
            chosen_action = choose_turn_action(available:, actor:)
            turns << execute_action(actor:, chosen_action:, round_number:, turn_index: turn_index + 1).with(gambit: RANDOM_GAMBIT)
            bonus_turn = war_magic_turn(actor:, chosen_action:, round_number:, turn_index: turn_index + 1)
            turns << bonus_turn if bonus_turn
          end

          extra_turn = action_surge_turn(actor:, round_number:, turn_index: turn_index + 1)
          turns << extra_turn if extra_turn
        end

        end_log = turn_passive_log(actor:, trigger: :turn_end, round_number:, turn_index: turn_index + 1)
        turns << end_log if end_log
      end

      turns
    end

    # Enabled gambits by priority, loaded once per simulation. Works on Gambit objects (saved or not),
    # never querying mid-turn, so a snapshot of the rules can stand in for the owner's own: with a copy
    # (gambits:), unsaved gambits rebuilt from it, logged with the copy's own label.
    def enabled_gambits(actor:)
      (@enabled_gambits ||= {})[actor.id] ||= if @gambit_settings
        gambit_snapshots(actor).select { |rule| rule["enabled"] }.map do |rule|
          Gambit.new(rule.slice(*Gambit::SNAPSHOT_ATTRIBUTES)).tap { |gambit| @gambit_labels[gambit] = rule["label"] }
        end
      else
        actor.gambits.select(&:enabled?).sort_by(&:position)
      end
    end

    # Every rule of the combatant (enabled or not) by priority, as Gambit#snapshot hashes.
    def gambit_snapshots(combatant)
      rules = @gambit_settings ? @gambit_settings.fetch(combatant.id.to_s, []) : combatant.gambits.map(&:snapshot)
      rules.sort_by { |rule| rule["position"] }
    end

    # One gambit-driven evaluation of the list, logged as the turn's entries: the winning rule's action
    # (plus War Magic's bonus attack, never on the extra action), or an idle entry. An Action Surge rule
    # spends one use, logs a marker and runs the list twice more (normal action, then the extra one),
    # with surge rules skipped inside both, so a surge never chains into another.
    def gambit_turns(actor:, gambits:, round_number:, turn_index:, surging: false, extra: false)
      return [] if combat_over?

      chosen_action = choose_gambit_action(actor:, gambits:, available: available_actions_for(actor:), surging:)
      return [ idle_turn(actor:, round_number:, turn_index:).with(extra:) ] unless chosen_action

      if chosen_action.action_surge?
        consume_feature_use!(actor:, class_feature_id: chosen_action.class_feature.id)
        marker = idle_turn(actor:, round_number:, turn_index:).with(action: { type: :action_surge }, gambit: gambit_log(chosen_action.gambit))
        return [ marker,
                 *gambit_turns(actor:, gambits:, round_number:, turn_index:, surging: true),
                 *gambit_turns(actor:, gambits:, round_number:, turn_index:, surging: true, extra: true) ]
      end

      return [ gambit_turn(actor:, chosen_action:, round_number:, turn_index:).with(extra: true) ] if extra

      [ gambit_turn(actor:, chosen_action:, round_number:, turn_index:),
        (war_magic_turn(actor:, chosen_action:, round_number:, turn_index:) unless combat_over?) ].compact
    end

    # FFXII-style choice: the first enabled gambit (top to bottom) whose action is available right now
    # and whose condition finds a target wins. Nil when none fires. Never draws from @rng.
    # surging: inside an Action Surge, whose rules are skipped.
    def choose_gambit_action(actor:, gambits:, available:, surging: false)
      surge = action_surge_action(actor:) unless surging
      available += [ surge ] if surge

      gambits.each do |gambit|
        action = available.find { |candidate| gambit_action?(gambit:, action: candidate) }
        next unless action
        next if gambit.condition_resource_at_least? && !gambit_resource_at_least?(actor:, action:, minimum: gambit.condition_value)

        target = gambit_target(actor:, gambit:)
        return action.with(target:, gambit:) if target
      end

      nil
    end

    def gambit_action?(gambit:, action:)
      case gambit.action_kind
      when "attack" then action.type == :attack
      when "class_feature" then action.class_feature&.id == gambit.class_feature_id
      when "spell" then action.spell? && action.spell.id == gambit.spell_id
      end
    end

    # Action Surge as a gambit action: unlocked and with a use left.
    def action_surge_action(actor:)
      unlock = feature_book(actor).unlock_with("extra_action")
      uses = unlock && @uses_remaining.dig(actor.id, unlock.class_feature_id)
      Combat::ActionOption.new(type: :action_surge, class_feature: unlock.class_feature, uses_remaining: uses) if uses.is_a?(Integer) && uses.positive?
    end

    # The actor's remaining resource for the rule's own action: spell slots of the spell's level, else the
    # feature's uses (the superiority-dice pool for maneuvers). Unlimited uses always pass.
    def gambit_resource_at_least?(actor:, action:, minimum:)
      remaining = action.spell? ? actor.available_spell_slots[action.spell.level].to_i : action.uses_remaining
      !remaining.is_a?(Integer) || remaining >= minimum
    end

    def gambit_log(gambit)
      { position: gambit.position, rule: @gambit_labels[gambit] || gambit.label }
    end

    # Candidates are the living combatants on the rule's side, in initiative order; the condition picks
    # one (ties go to whoever comes first in initiative). Nil when nobody qualifies.
    def gambit_target(actor:, gambit:)
      pool = case gambit.target
      when "self" then [ actor ]
      when "ally" then own_party_for(actor)
      when "enemy" then enemy_party_for(actor)
      end
      candidates = @initiative_order.select { |combatant| pool.include?(combatant) && !combatant.dead? }

      case gambit.condition
      when "any", "resource_at_least" then candidates.first # the resource is checked in choose_gambit_action
      when "hp_below" then candidates.find { |combatant| combatant.current_hit_points * 100 < gambit.condition_value * combatant.max_hit_points }
      when "hp_above" then candidates.find { |combatant| combatant.current_hit_points * 100 > gambit.condition_value * combatant.max_hit_points }
      when "lowest_hp" then candidates.min_by(&:current_hit_points)
      when "highest_hp" then candidates.max_by(&:current_hit_points)
      when "marked" then candidates.find { |combatant| marked_for?(actor:, target: combatant) }
      when "unmarked" then candidates.find { |combatant| !marked_for?(actor:, target: combatant) }
      else raise ArgumentError, "Unsupported gambit condition: #{gambit.condition.inspect}"
      end
    end

    # The actor's next weapon attack on the target would use up someone else's Distracting Strike mark.
    def marked_for?(actor:, target:)
      @advantage_marks.fetch(target.id, []).any? { |source_id| source_id != actor.id }
    end

    def gambit_turn(actor:, chosen_action:, round_number:, turn_index:)
      execute_action(actor:, chosen_action:, round_number:, turn_index:).with(gambit: gambit_log(chosen_action.gambit))
    end

    # A gambit-driven actor whose rules all failed stands idle for the turn.
    def idle_turn(actor:, round_number:, turn_index:)
      turn_record(actor:, round_number:, turn_index:, action: { type: :idle }, gambit: IDLE_GAMBIT)
    end

    # The turn's log entry; the header (round, turn, actor) is built in Combat::TurnRecord.for.
    def turn_record(actor:, round_number:, turn_index:, **entry)
      Combat::TurnRecord.for(actor:, party: party_for(actor), round: round_number, turn: turn_index, **entry)
    end

    # Action Surge for an actor without gambits: if the actor has an unused Action Surge, take one extra
    # action right after their normal action. Not recursive — the extra action never grants another one.
    # A gambit-driven actor only surges through a rule (see gambit_turns).
    def action_surge_turn(actor:, round_number:, turn_index:)
      return nil if combat_over?

      unlock = feature_book(actor).unlock_with("extra_action")
      return nil unless unlock

      uses = @uses_remaining.dig(actor.id, unlock.class_feature_id)
      return nil unless uses.is_a?(Integer) && uses.positive?

      available = available_actions_for(actor:)
      return nil if available.empty?

      chosen_action = available.sample(random: @rng)
      consume_feature_use!(actor:, class_feature_id: unlock.class_feature_id)
      execute_action(actor:, chosen_action:, round_number:, turn_index:).with(extra: true, gambit: RANDOM_GAMBIT)
    end

    # War Magic / Improved War Magic (a grants_activity, Combat::FeatureBook#weapon_attacks_after): casting a
    # spell as the turn's normal action grants its count (one) of bonus weapon attacks right after it (not the
    # Attack action, so no Extra Attack). Not recursive
    # (a plain attack, via execute_attack_action, never triggers another one) and never fired from the
    # Action Surge extra action — only from the turn's normal chosen_action.
    # A gambit-driven actor aims it without @rng: the spell's target if it is a living enemy, else the
    # first living enemy in initiative order. The bonus entry carries the gambit of the spell's entry.
    def war_magic_turn(actor:, chosen_action:, round_number:, turn_index:)
      attacks = feature_book(actor).weapon_attacks_after(chosen_action.spell) if chosen_action.spell?
      return nil unless attacks

      if chosen_action.chosen_by_gambit?
        spell_target = chosen_action.target
        focus = enemy_party_for(actor).include?(spell_target) && !spell_target.dead? ? spell_target : first_living_enemy(actor:)
      end
      gambit = chosen_action.chosen_by_gambit? ? gambit_log(chosen_action.gambit) : RANDOM_GAMBIT
      execute_attack_action(actor:, round_number:, turn_index:, focus:, attacks:).with(bonus: true, gambit:)
    end

    def turn_passive_log(actor:, trigger:, round_number:, turn_index:)
      results = trigger == :turn_start ? actor.apply_start_of_turn_passives! : actor.apply_end_of_turn_passives!
      return nil if results.empty?

      turn_record(actor:, round_number:, turn_index:, action: { type: :turn_passive, trigger: trigger.to_s }, results: serialize_effect_results(results:))
    end

    def available_actions_for(actor:)
      actions = [ Combat::ActionOption.new(type: :attack) ]
      book = feature_book(actor)

      book.unlocks.each do |unlock|
        feature = unlock.class_feature
        payload = book.action_payload(feature)
        next unless payload

        uses = @uses_remaining.dig(actor.id, book.resource_feature_id(feature))
        next if uses.is_a?(Integer) && uses <= 0

        actions << Combat::ActionOption.new(type: :class_feature, class_feature: feature, payload:, uses_remaining: uses)
      end

      actor.spells.each do |spell|
        next if spell.effect_payload.blank?
        next unless spell.cantrip? || actor.available_spell_slots[spell.level].to_i.positive?

        actions << Combat::ActionOption.new(type: :cast_spell, spell:, payload: spell.effect_payload.deep_stringify_keys)
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
      spell_options = available.select(&:spell?)
      if actor.spellcasting_feature.present? && spell_options.any?
        other_options = available - spell_options
        (@rng.rand < 0.5 ? other_options : spell_options).sample(random: @rng)
      else
        available.sample(random: @rng)
      end
    end

    def execute_action(actor:, chosen_action:, round_number:, turn_index:)
      case chosen_action.type
      when :attack
        execute_attack_action(actor:, round_number:, turn_index:, gambit: chosen_action.gambit)
      when :class_feature
        if chosen_action.maneuver?
          execute_attack_action(actor:, round_number:, turn_index:, maneuver: chosen_action, gambit: chosen_action.gambit)
        else
          execute_class_feature_action(actor:, chosen_action:, round_number:, turn_index:)
        end
      when :cast_spell
        execute_cast_spell_action(actor:, chosen_action:, round_number:, turn_index:)
      else
        raise ArgumentError, "Unsupported action type: #{chosen_action.type}"
      end
    end

    # maneuver: the chosen class_feature action of a maneuver (payload "applies_to" weapon_attack). Its
    # die is added to the damage of the first attack that hits; a miss spends nothing.
    # gambit: the rule that chose this action. Every attack re-runs its target pick (the first one lands
    # on the target the rule just chose), falling back to the first living enemy in initiative order.
    # focus: a fixed target (War Magic for a gambit-driven actor), with the same fallback once it is down.
    # attacks: how many attacks to make; the Attack action's attacks_per_action (Extra Attack) by default.
    def execute_attack_action(actor:, round_number:, turn_index:, maneuver: nil, gambit: nil, focus: nil, attacks: actor.attacks_per_action)
      enemy_party = enemy_party_for(actor)
      entries = []
      pending_maneuver = maneuver

      next_target = lambda do
        if gambit
          gambit_target(actor:, gambit:) || first_living_enemy(actor:)
        elsif focus
          focus.dead? ? first_living_enemy(actor:) : focus
        else
          alive_combatants(enemy_party).sample(random: @rng)
        end
      end
      action = Combat::CombatAction.new(source_type: :attack, source_id: nil, actor:)

      Combat::ActionRunner.attack(action:, next_target:, attacks:, advantage_against: ->(target) { consume_advantage_mark(target:, attacker: actor) }) do |target, result, advantage|
        hit = result.attack_roll.hit
        damage = result.roll_outcome.total

        @eldritch_strike_pending[target.id] = actor.id if hit && feature_book(actor).rider?(event: "weapon_hit", applies: "disadvantage_on_next_save")

        rider = apply_maneuver_rider(actor:, target:, maneuver: pending_maneuver, crit: result.attack_roll.crit) if pending_maneuver && hit
        pending_maneuver = nil if rider

        entries << {
          kind: :attack,
          target_id: target.id,
          target_name: target.name,
          success: hit,
          advantage: advantage,
          rider: rider,
          damage: hit ? damage : 0,
          hp_before: result.hp_before,
          hp_after: result.hp_after,
          attack_roll: {
            natural: result.attack_roll.natural,
            total: result.attack_roll.total,
            crit: result.attack_roll.crit,
            damage: damage
          }
        }
      end

      turn_record(actor:, round_number:, turn_index:, action: { type: :attack, maneuver_name: maneuver&.class_feature&.name }.compact, results: entries)
    end

    # Adds the maneuver's die to a weapon attack that just hit: rolls it through the effect pipeline
    # (doubled on a critical hit), spends a superiority die and applies the payload's debuff, if any.
    # ponytail: the die lands as its own damage instance (own log line, own resistance rounding), not
    # inside the weapon's single damage roll; merge them if that ever distorts a metric.
    def apply_maneuver_rider(actor:, target:, maneuver:, crit:)
      feature = maneuver.class_feature
      action = Combat::CombatAction.new(source_type: :class_feature, source_id: feature.id, actor:, targets: [ target ])
      results = Combat::ActionRunner.call(action:, crit:)
      consume_feature_use!(actor:, class_feature_id: feature_book(actor).resource_feature_id(feature))

      # ponytail: `debuff` is one string with one supported value, no duration and one effect per payload;
      # replace it with a list of status applications once a feature or spell applies a status (issue #45).
      debuff = maneuver.payload["debuff"]
      case debuff
      when nil then nil
      when "next_attack_advantage" then @advantage_marks[target.id] << actor.id
      else raise ArgumentError, "Unsupported debuff: #{debuff.inspect}"
      end

      serialize_effect_results(results:).first.merge(feature_name: feature.name, debuff:).compact
    end

    # The first attacker other than a mark's owner uses that mark up and rolls with advantage.
    def consume_advantage_mark(target:, attacker:)
      marks = @advantage_marks[target.id]
      index = marks.index { |source_id| source_id != attacker.id }
      return false unless index

      marks.delete_at(index)
      true
    end

    def execute_class_feature_action(actor:, chosen_action:, round_number:, turn_index:)
      feature = chosen_action.class_feature
      payload = chosen_action.payload
      target = chosen_action.chosen_by_gambit? ? chosen_action.target : resolve_feature_target(actor:, payload:)

      action = Combat::CombatAction.new(
        source_type: :class_feature,
        source_id: feature.id,
        actor: actor,
        targets: target.nil? ? [] : [ target ]
      )

      indomitable_unlock = target && feature_book(target).unlock_with("reroll_save")
      reroll_saving_throw = indomitable_unlock && indomitable_available?(combatant: target, unlock: indomitable_unlock)

      results = Combat::ActionRunner.call(action:, reroll_saving_throw: !!reroll_saving_throw)
      consume_feature_use!(actor:, class_feature_id: feature_book(actor).resource_feature_id(feature))

      if reroll_saving_throw
        results.each do |result|
          next unless result.saving_throw&.rerolled

          consume_feature_use!(actor: target, class_feature_id: indomitable_unlock.class_feature_id)
        end
      end

      turn_record(actor:, round_number:, turn_index:, results: serialize_effect_results(results:), action: {
        type: :class_feature,
        feature_id: feature.id,
        feature_slug: feature.slug,
        feature_name: feature.name,
        target_type: payload["target"]
      })
    end

    def execute_cast_spell_action(actor:, chosen_action:, round_number:, turn_index:)
      spell = chosen_action.spell
      payload = chosen_action.payload
      target = chosen_action.chosen_by_gambit? ? chosen_action.target : resolve_feature_target(actor:, payload:)

      disadvantage_on_save = target && @eldritch_strike_pending[target.id] == actor.id
      @eldritch_strike_pending.delete(target.id) if disadvantage_on_save

      results = actor.cast_spell(slug: spell.slug, targets: [ target ].compact, disadvantage_on_save: !!disadvantage_on_save)

      turn_record(actor:, round_number:, turn_index:, results: serialize_effect_results(results:), action: {
        type: :cast_spell,
        spell_id: spell.id,
        spell_slug: spell.slug,
        spell_name: spell.name,
        target_type: payload["target"]
      })
    end

    def serialize_effect_results(results:)
      results.map do |result|
        serialized = {
          kind: result.kind,
          applied: result.applied,
          amount: result.amount,
          hp_before: result.hp_before,
          hp_after: result.hp_after,
          roll_outcome: {
            expression: result.roll_outcome.expression,
            resolved_expression: result.roll_outcome.resolved_expression,
            dice: result.roll_outcome.dice,
            rolls: result.roll_outcome.rolls,
            modifiers: result.roll_outcome.modifiers,
            total: result.roll_outcome.total
          }
        }
        serialized[:attack_roll] = result.attack_roll.to_h if result.attack_roll
        serialized
      end
    end

    # The payload's "target" says who may be picked: self, enemy (opposing party) or ally (own party,
    # actor included). Nil when nobody valid is left alive.
    def resolve_feature_target(actor:, payload:)
      candidates = case payload["target"]
      when "self" then [ actor ]
      when "enemy" then alive_combatants(enemy_party_for(actor))
      when "ally" then alive_combatants(own_party_for(actor))
      else raise ArgumentError, "Unsupported target: #{payload["target"].inspect}"
      end

      candidates.sample(random: @rng)
    end

    def consume_feature_use!(actor:, class_feature_id:)
      uses = @uses_remaining.dig(actor.id, class_feature_id)
      return unless uses.is_a?(Integer)

      @uses_remaining[actor.id][class_feature_id] = [ uses - 1, 0 ].max
    end

    def indomitable_available?(combatant:, unlock:)
      uses = @uses_remaining.dig(combatant.id, unlock.class_feature_id)
      uses.is_a?(Integer) && uses.positive?
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
        initiative: @initiative.map { |entry| { actor_id: entry[:combatant].id, natural: entry[:natural], total: entry[:total] } },
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

    def own_party_for(combatant)
      party_for(combatant) == :party_one ? @party_one : @party_two
    end

    def first_living_enemy(actor:)
      enemy_party = enemy_party_for(actor)
      @initiative_order.find { |combatant| enemy_party.include?(combatant) && !combatant.dead? }
    end

    def enemy_party_for(combatant)
      party_for(combatant) == :party_one ? @party_two : @party_one
    end
end
