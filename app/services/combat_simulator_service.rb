class CombatSimulatorService
  DEFAULT_MAX_ROUNDS = 20

  # Raised from #call when abort_if returns true; the partial simulation is discarded.
  class Aborted < StandardError; end

  # The `gambit` of a decision entry when no rule drove it: a random pick, or a gambit-driven actor
  # whose rules all failed.
  RANDOM_GAMBIT = "aleatório"
  IDLE_GAMBIT = "nenhum aplicável: parado"

  # abort_if: optional callable checked before every round (e.g. a batch cancelled from the UI).
  # party_one, party_two: the character sheets; each fights as a Combat::Participant (built in initialize_state),
  # so the sheets are only read.
  # gambits: optional copy of the rules, { character id (string) => [Gambit#snapshot, ...] } (a batch's
  # gambit_settings); the simulation runs and logs from it instead of each combatant's own gambits.
  # hit_points: optional starting HP, { character id => HP } (an experiment's); the sheet's maximum otherwise.
  def initialize(party_one:, party_two:, seed: nil, max_rounds: DEFAULT_MAX_ROUNDS, abort_if: nil, gambits: nil, hit_points: {})
    raise ArgumentError, "Both parties must be Arrays" unless party_one.is_a?(Array) && party_two.is_a?(Array)
    raise ArgumentError, "Parties must not be empty" if party_one.empty? || party_two.empty?

    @sheets = [ party_one, party_two ]
    @hit_points = hit_points.to_h.transform_keys(&:to_i)
    @seed = seed
    @abort_if = abort_if
    @gambit_settings = gambits
    @gambit_labels = {}.compare_by_identity
    @max_rounds = Integer(max_rounds)
    raise ArgumentError, "max_rounds must be greater than 0" if @max_rounds <= 0

    @rng = @seed.nil? ? Random.new : Random.new(@seed)
    @round_log = []
  end

  def call
    with_seed do
      initialize_state
      initiative_order = @encounter.initiative_order = build_initiative_order

      round_number = 0

      while round_number < @max_rounds
        break if @encounter.over?
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

    # In party order, so the uses rolled from a formula (Combat::Participant.new) keep the RNG sequence.
    def initialize_state
      party_one, party_two = @sheets.map do |sheets|
        sheets.map { |sheet| Combat::Participant.new(sheet, hit_points: @hit_points[sheet.id]) }
      end
      @encounter = Combat::Encounter.new(party_one:, party_two:)
    end

    attr_reader :encounter

    # One d20 per combatant, in party order (the RNG sequence), sorted by total with ties kept in that
    # order. The rolls stay in @initiative for the result.
    def build_initiative_order
      initiative_entries = @encounter.participants.each_with_index.map do |combatant, index|
        roll = Dice.d20(modifier: combatant.initiative)
        { combatant:, natural: roll.natural, total: roll.total, tie_breaker: index }
      end

      @initiative = initiative_entries.sort_by { |entry| [ -entry[:total], entry[:tie_breaker] ] }
      @initiative.map { |entry| entry[:combatant] }
    end

    def execute_round(round_number:, initiative_order:)
      turns = []

      initiative_order.each_with_index do |actor, turn_index|
        @encounter.start_turn(actor)
        next if actor.dead?
        break if @encounter.over?

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
      return [] if @encounter.over?

      chosen_action = choose_gambit_action(actor:, gambits:, available: available_actions_for(actor:), surging:)
      return [ idle_turn(actor:, round_number:, turn_index:).with(extra:) ] unless chosen_action

      if chosen_action.action_surge?
        actor.spend_use!(chosen_action.class_feature.id)
        marker = idle_turn(actor:, round_number:, turn_index:).with(action: { type: :action_surge }, gambit: gambit_log(chosen_action.gambit))
        return [ marker,
                 *gambit_turns(actor:, gambits:, round_number:, turn_index:, surging: true),
                 *gambit_turns(actor:, gambits:, round_number:, turn_index:, surging: true, extra: true) ]
      end

      return [ gambit_turn(actor:, chosen_action:, round_number:, turn_index:).with(extra: true) ] if extra

      [ gambit_turn(actor:, chosen_action:, round_number:, turn_index:),
        (war_magic_turn(actor:, chosen_action:, round_number:, turn_index:) unless @encounter.over?) ].compact
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
      unlock = actor.feature_book.unlock_with("extra_action")
      uses = unlock && actor.uses_left(unlock.class_feature_id)
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
      when "ally" then @encounter.allies_of(actor)
      when "enemy" then @encounter.enemies_of(actor)
      end
      candidates = @encounter.initiative_order.select { |combatant| pool.include?(combatant) && !combatant.dead? }

      case gambit.condition
      when "any", "resource_at_least" then candidates.first # the resource is checked in choose_gambit_action
      when "hp_below" then candidates.find { |combatant| combatant.current_hit_points * 100 < gambit.condition_value * combatant.max_hit_points }
      when "hp_above" then candidates.find { |combatant| combatant.current_hit_points * 100 > gambit.condition_value * combatant.max_hit_points }
      when "lowest_hp" then candidates.min_by(&:current_hit_points)
      when "highest_hp" then candidates.max_by(&:current_hit_points)
      when "marked" then candidates.find { |combatant| combatant.status?("next_attack_advantage", not_from: actor) }
      when "unmarked" then candidates.find { |combatant| !combatant.status?("next_attack_advantage", not_from: actor) }
      else raise ArgumentError, "Unsupported gambit condition: #{gambit.condition.inspect}"
      end
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
      Combat::TurnRecord.for(actor:, party: @encounter.party_for(actor), round: round_number, turn: turn_index, **entry)
    end

    # Action Surge for an actor without gambits: if the actor has an unused Action Surge, take one extra
    # action right after their normal action. Not recursive — the extra action never grants another one.
    # A gambit-driven actor only surges through a rule (see gambit_turns).
    def action_surge_turn(actor:, round_number:, turn_index:)
      return nil if @encounter.over?

      unlock = actor.feature_book.unlock_with("extra_action")
      return nil unless unlock

      uses = actor.uses_left(unlock.class_feature_id)
      return nil unless uses.is_a?(Integer) && uses.positive?

      available = available_actions_for(actor:)
      return nil if available.empty?

      chosen_action = available.sample(random: @rng)
      actor.spend_use!(unlock.class_feature_id)
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
      attacks = actor.feature_book.weapon_attacks_after(chosen_action.spell) if chosen_action.spell?
      return nil unless attacks

      if chosen_action.chosen_by_gambit?
        spell_target = chosen_action.target
        focus = @encounter.enemies_of(actor).include?(spell_target) && !spell_target.dead? ? spell_target : @encounter.first_living_enemy(actor)
      end
      gambit = chosen_action.chosen_by_gambit? ? gambit_log(chosen_action.gambit) : RANDOM_GAMBIT
      execute_attack_action(actor:, round_number:, turn_index:, focus:, attacks:).with(bonus: true, gambit:)
    end

    def turn_passive_log(actor:, trigger:, round_number:, turn_index:)
      results = actor.apply_turn_passives!(trigger: trigger.to_s)
      return nil if results.empty?

      turn_record(actor:, round_number:, turn_index:, action: { type: :turn_passive, trigger: trigger.to_s }, results: serialize_effect_results(results:))
    end

    def available_actions_for(actor:)
      actions = [ Combat::ActionOption.new(type: :attack) ]
      book = actor.feature_book

      book.unlocks.each do |unlock|
        feature = unlock.class_feature
        payload = book.action_payload(feature)
        next unless payload

        uses = actor.uses_left(book.resource_feature_id(feature))
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
      enemy_party = @encounter.enemies_of(actor)
      entries = []
      pending_maneuver = maneuver

      next_target = lambda do
        if gambit
          gambit_target(actor:, gambit:) || @encounter.first_living_enemy(actor)
        elsif focus
          focus.dead? ? @encounter.first_living_enemy(actor) : focus
        else
          @encounter.alive(enemy_party).sample(random: @rng)
        end
      end
      action = Combat::CombatAction.new(source_type: :attack, source_id: nil, actor:)

      # The first weapon attack against a target marked by others (Distracting Strike) uses every such mark up
      # and rolls with advantage once: advantage does not stack. The attacker's own mark stays.
      advantage_against = ->(target) { target.take_statuses("next_attack_advantage", not_from: actor).any? }
      Combat::ActionRunner.attack(action:, next_target:, attacks:, advantage_against:) do |target, result, advantage|
        riders = []
        if result.attack_roll.hit
          eldritch_strike = actor.feature_book.rider(event: "weapon_hit", applies: "disadvantage_on_next_save")
          if eldritch_strike
            # ponytail: no end of its own (5e: until the end of the attacker's next turn); only a save uses it up.
            target.add_status(Combat::Status.new(kind: "disadvantage_on_next_save", source: actor, ends: nil))
            riders << Combat::Rider.for(feature: eldritch_strike, statuses: [ "disadvantage_on_next_save" ])
          end
          if pending_maneuver
            riders << apply_maneuver_rider(actor:, target:, maneuver: pending_maneuver, crit: result.attack_roll.crit)
            pending_maneuver = nil
          end
        end

        # The weapon's damage logs like any effect (amount, hp, roll_outcome, attack_roll); applied is left
        # out, the same as the attack roll's hit.
        effect = serialize_effect_results(results: [ result ]).first.except(:kind, :applied)
        entries << { kind: :attack, target_id: target.id, target_name: target.name, advantage:, riders: riders.map(&:to_h), **effect }
      end

      turn_record(actor:, round_number:, turn_index:, action: { type: :attack, riders: maneuver && [ Combat::Rider.for(feature: maneuver.class_feature).to_h ] }.compact, results: entries)
    end

    # Adds the maneuver's die to a weapon attack that just hit: rolls it through the effect pipeline
    # (doubled on a critical hit), spends a superiority die and applies the payload's statuses to the target,
    # if any (Distracting Strike: next_attack_advantage). Returns the applied Combat::Rider, with their kinds.
    # ponytail: the die lands as its own damage instance (own log line, own resistance rounding), not
    # inside the weapon's single damage roll; merge them if that ever distorts a metric.
    def apply_maneuver_rider(actor:, target:, maneuver:, crit:)
      feature = maneuver.class_feature
      action = Combat::CombatAction.new(source_type: :class_feature, source_id: feature.id, actor:, targets: [ target ])
      results = Combat::ActionRunner.call(action:, crit:)
      actor.spend_use!(actor.feature_book.resource_feature_id(feature))

      statuses = maneuver.payload.fetch("statuses", [])
      statuses.each { |status| target.add_status(Combat::Status.new(kind: status["kind"], source: actor, ends: status["ends"])) }

      Combat::Rider.for(feature:, effect: serialize_effect_results(results:).first.compact, statuses: statuses.pluck("kind"))
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

      indomitable_unlock = target && target.feature_book.unlock_with("reroll_save")
      reroll_saving_throw = indomitable_unlock && target.uses_left(indomitable_unlock.class_feature_id).to_i.positive?

      results = Combat::ActionRunner.call(action:, reroll_saving_throw: !!reroll_saving_throw)
      actor.spend_use!(actor.feature_book.resource_feature_id(feature))

      if reroll_saving_throw
        results.each do |result|
          next unless result.saving_throw&.rerolled

          target.spend_use!(indomitable_unlock.class_feature_id)
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

      # Any spell of the actor at the target uses up the actor's Eldritch Strike mark on it, save or not.
      disadvantage_on_save = target&.take_statuses("disadvantage_on_next_save", from: actor).present?

      results = actor.cast_spell(spell, targets: [ target ].compact, disadvantage_on_save:)

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
      when "enemy" then @encounter.alive(@encounter.enemies_of(actor))
      when "ally" then @encounter.alive(@encounter.allies_of(actor))
      else raise ArgumentError, "Unsupported target: #{payload["target"].inspect}"
      end

      candidates.sample(random: @rng)
    end

    def build_result(round_number:)
      party_one_alive = @encounter.alive(@encounter.party_one).any?
      party_two_alive = @encounter.alive(@encounter.party_two).any?

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
end
