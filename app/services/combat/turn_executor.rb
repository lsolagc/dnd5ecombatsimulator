module Combat
  # One actor's turn in an encounter (glossary: Turn executor): decides the action, by the actor's gambits
  # (Combat::GambitPolicy) or at random from rng, chains Action Surge and War Magic, runs the actions through
  # the Combat::* pipeline and returns the Combat::TurnRecords. rng draws the random choices only (picks and
  # targets); the dice roll on the global Random, which Combat::Simulator seeds.
  #
  # Public: #take_turn (the whole turn), and its pieces a caller can run on their own: #run (one chosen
  # option), #war_magic_turn, #action_surge_turn, #choose_at_random and #random_target.
  class TurnExecutor
    # The `gambit` of a decision entry when no rule drove it: a random pick, or a gambit-driven actor whose
    # rules all failed.
    RANDOM_GAMBIT = "aleatório"
    IDLE_GAMBIT = "nenhum aplicável: parado"

    def initialize(encounter:, rng:, policy:)
      @encounter = encounter
      @rng = rng
      @policy = policy
    end

    # The actor's decision entries for the turn (the turn passives are the simulator's): by its gambits when
    # it has an enabled one, else a random option, War Magic's bonus attack and the random Action Surge.
    def take_turn(actor, round:, turn:)
      return gambit_turns(actor:, round:, turn:) if @policy.rules_for(actor).any?

      records = []
      options = actor.action_options
      if options.any?
        option = choose_at_random(actor:, options:)
        records << run(actor:, option:, round:, turn:).with(gambit: RANDOM_GAMBIT)
        bonus = war_magic_turn(actor:, option:, round:, turn:)
        records << bonus if bonus
      end

      extra = action_surge_turn(actor:, round:, turn:)
      records << extra if extra
      records
    end

    # Runs a chosen option as an action and returns its TurnRecord, without a gambit (the caller logs it).
    # A gambit's pick (ActionOption#with target and gambit) aims at the rule's target; otherwise the target
    # is random (#random_target).
    def run(actor:, option:, round:, turn:)
      case option.type
      when :attack
        attack(actor:, round:, turn:, gambit: option.gambit)
      when :class_feature
        if option.maneuver?
          attack(actor:, round:, turn:, maneuver: option, gambit: option.gambit)
        else
          use_feature(actor:, option:, round:, turn:)
        end
      when :cast_spell
        cast_spell(actor:, option:, round:, turn:)
      else
        raise ArgumentError, "Unsupported action type: #{option.type}"
      end
    end

    # War Magic / Improved War Magic (a grants_activity, Combat::FeatureBook#weapon_attacks_after): casting a
    # spell as the turn's normal action grants its count (one) of bonus weapon attacks right after it (not the
    # Attack action, so no Extra Attack). Not recursive (a plain attack never triggers another one) and never
    # fired from the Action Surge extra action — only from the turn's normal option. Nil when none follows.
    # A gambit-driven actor aims it without rng: the spell's target if it is a living enemy, else the first
    # living enemy in initiative order. The bonus entry carries the gambit of the spell's entry.
    def war_magic_turn(actor:, option:, round:, turn:)
      attacks = actor.feature_book.weapon_attacks_after(option.spell) if option.spell?
      return nil unless attacks

      if option.chosen_by_gambit?
        spell_target = option.target
        focus = @encounter.enemies_of(actor).include?(spell_target) && !spell_target.dead? ? spell_target : @encounter.first_living_enemy(actor)
      end
      gambit = option.chosen_by_gambit? ? @policy.log(option.gambit) : RANDOM_GAMBIT
      attack(actor:, round:, turn:, focus:, attacks:).with(bonus: true, gambit:)
    end

    # Action Surge for an actor without gambits: with an unused Action Surge, one extra random action right
    # after its normal one, spending a use. Not recursive: the extra action never grants another one. Nil
    # when it does not surge. A gambit-driven actor only surges through a rule (#take_turn).
    def action_surge_turn(actor:, round:, turn:)
      return nil if @encounter.over?

      surge = actor.action_surge_option
      return nil unless surge

      options = actor.action_options
      return nil if options.empty?

      option = options.sample(random: @rng)
      actor.spend_use!(surge.class_feature.id)
      run(actor:, option:, round:, turn:).with(extra: true, gambit: RANDOM_GAMBIT)
    end

    # Deliberately primitive turn AI: a spellcaster with at least one castable spell flips a coin between the
    # "physical" branch (attack + class features, uniform) and the "spell" branch (cast_spell options,
    # uniform). Non-casters, or casters with nothing castable right now, keep the uniform sample over
    # everything — no coin flip — so rng draws stay unchanged for the vast majority of actors.
    def choose_at_random(actor:, options:)
      spell_options = options.select(&:spell?)
      if actor.spellcasting_feature.present? && spell_options.any?
        other_options = options - spell_options
        (@rng.rand < 0.5 ? other_options : spell_options).sample(random: @rng)
      else
        options.sample(random: @rng)
      end
    end

    # A random target of the payload's "target" kind: self, enemy (opposing party) or ally (own party, actor
    # included). Nil when nobody valid is left alive.
    def random_target(actor:, payload:)
      candidates = case payload["target"]
      when "self" then [ actor ]
      when "enemy" then @encounter.alive(@encounter.enemies_of(actor))
      when "ally" then @encounter.alive(@encounter.allies_of(actor))
      else raise ArgumentError, "Unsupported target: #{payload["target"].inspect}"
      end

      candidates.sample(random: @rng)
    end

    private

      # One gambit-driven evaluation of the list, logged as the turn's entries: the winning rule's action
      # (plus War Magic's bonus attack, never on the extra action), or an idle entry. An Action Surge rule
      # spends one use, logs a marker and runs the list twice more (normal action, then the extra one), with
      # surge rules skipped inside both, so a surge never chains into another.
      def gambit_turns(actor:, round:, turn:, surging: false, extra: false)
        return [] if @encounter.over?

        option = @policy.choose(actor:, options: actor.action_options, surging:)
        return [ idle_turn(actor:, round:, turn:).with(extra:) ] unless option

        if option.action_surge?
          actor.spend_use!(option.class_feature.id)
          marker = idle_turn(actor:, round:, turn:).with(action: { type: :action_surge }, gambit: @policy.log(option.gambit))
          return [ marker,
                   *gambit_turns(actor:, round:, turn:, surging: true),
                   *gambit_turns(actor:, round:, turn:, surging: true, extra: true) ]
        end

        return [ gambit_turn(actor:, option:, round:, turn:).with(extra: true) ] if extra

        [ gambit_turn(actor:, option:, round:, turn:),
          (war_magic_turn(actor:, option:, round:, turn:) unless @encounter.over?) ].compact
      end

      def gambit_turn(actor:, option:, round:, turn:)
        run(actor:, option:, round:, turn:).with(gambit: @policy.log(option.gambit))
      end

      # A gambit-driven actor whose rules all failed stands idle for the turn.
      def idle_turn(actor:, round:, turn:)
        record(actor:, round:, turn:, action: { type: :idle }, gambit: IDLE_GAMBIT)
      end

      # maneuver: the chosen class_feature option of a maneuver (payload "applies_to" weapon_attack). Its die
      # is added to the damage of the first attack that hits; a miss spends nothing.
      # gambit: the rule that chose this action. Every attack re-runs its target pick (the first one lands on
      # the target the rule just chose), falling back to the first living enemy in initiative order.
      # focus: a fixed target (War Magic for a gambit-driven actor), with the same fallback once it is down.
      # attacks: how many attacks to make; the Attack action's attacks_per_action (Extra Attack) by default.
      def attack(actor:, round:, turn:, maneuver: nil, gambit: nil, focus: nil, attacks: actor.attacks_per_action)
        enemy_party = @encounter.enemies_of(actor)
        entries = []
        pending_maneuver = maneuver

        next_target = lambda do
          if gambit
            @policy.target(actor:, gambit:) || @encounter.first_living_enemy(actor)
          elsif focus
            focus.dead? ? @encounter.first_living_enemy(actor) : focus
          else
            @encounter.alive(enemy_party).sample(random: @rng)
          end
        end
        action = CombatAction.new(source_type: :attack, source_id: nil, actor:)

        # The first weapon attack against a target marked by others (Distracting Strike) uses every such mark up
        # and rolls with advantage once: advantage does not stack. The attacker's own mark stays.
        advantage_against = ->(target) { target.take_statuses("next_attack_advantage", not_from: actor).any? }
        ActionRunner.attack(action:, next_target:, attacks:, advantage_against:) do |target, result, advantage|
          riders = []
          if result.attack_roll.hit
            eldritch_strike = actor.feature_book.rider(event: "weapon_hit", applies: "disadvantage_on_next_save")
            if eldritch_strike
              # ponytail: no end of its own (5e: until the end of the attacker's next turn); only a save uses it up.
              target.add_status(Status.new(kind: "disadvantage_on_next_save", source: actor, ends: nil))
              riders << Rider.for(feature: eldritch_strike, statuses: [ "disadvantage_on_next_save" ])
            end
            if pending_maneuver
              riders << apply_maneuver_rider(actor:, target:, maneuver: pending_maneuver, crit: result.attack_roll.crit)
              pending_maneuver = nil
            end
          end

          # The weapon's damage logs like any effect (amount, hp, roll_outcome, attack_roll); applied is left
          # out, the same as the attack roll's hit.
          effect = TurnRecord.serialize_results([ result ]).first.except(:kind, :applied)
          entries << { kind: :attack, target_id: target.id, target_name: target.name, advantage:, riders: riders.map(&:to_h), **effect }
        end

        record(actor:, round:, turn:, action: { type: :attack, riders: maneuver && [ Rider.for(feature: maneuver.class_feature).to_h ] }.compact, results: entries)
      end

      # Adds the maneuver's die to a weapon attack that just hit: rolls it through the effect pipeline
      # (doubled on a critical hit), spends a superiority die and applies the payload's statuses to the target,
      # if any (Distracting Strike: next_attack_advantage). Returns the applied Combat::Rider, with their kinds.
      # ponytail: the die lands as its own damage instance (own log line, own resistance rounding), not
      # inside the weapon's single damage roll; merge them if that ever distorts a metric.
      def apply_maneuver_rider(actor:, target:, maneuver:, crit:)
        feature = maneuver.class_feature
        action = CombatAction.new(source_type: :class_feature, source_id: feature.id, actor:, targets: [ target ])
        results = ActionRunner.call(action:, crit:)
        actor.spend_use!(actor.feature_book.resource_feature_id(feature))

        statuses = maneuver.payload.fetch("statuses", [])
        statuses.each { |status| target.add_status(Status.new(kind: status["kind"], source: actor, ends: status["ends"])) }

        Rider.for(feature:, effect: TurnRecord.serialize_results(results).first.compact, statuses: statuses.pluck("kind"))
      end

      def use_feature(actor:, option:, round:, turn:)
        feature = option.class_feature
        payload = option.payload
        target = option.chosen_by_gambit? ? option.target : random_target(actor:, payload:)

        action = CombatAction.new(source_type: :class_feature, source_id: feature.id, actor:, targets: target.nil? ? [] : [ target ])

        indomitable_unlock = target && target.feature_book.unlock_with("reroll_save")
        reroll_saving_throw = indomitable_unlock && target.uses_left(indomitable_unlock.class_feature_id).to_i.positive?

        results = ActionRunner.call(action:, reroll_saving_throw: !!reroll_saving_throw)
        actor.spend_use!(actor.feature_book.resource_feature_id(feature))

        if reroll_saving_throw
          results.each do |result|
            next unless result.saving_throw&.rerolled

            target.spend_use!(indomitable_unlock.class_feature_id)
          end
        end

        record(actor:, round:, turn:, results: TurnRecord.serialize_results(results), action: {
          type: :class_feature,
          feature_id: feature.id,
          feature_slug: feature.slug,
          feature_name: feature.name,
          target_type: payload["target"]
        })
      end

      def cast_spell(actor:, option:, round:, turn:)
        spell = option.spell
        payload = option.payload
        target = option.chosen_by_gambit? ? option.target : random_target(actor:, payload:)

        # Only a spell that calls for a save uses up the actor's Eldritch Strike mark on the target (5e: the next
        # saving throw against the actor's spell); a spell attack such as Fire Bolt leaves it for a later save.
        disadvantage_on_save = payload["save"].present? && target&.take_statuses("disadvantage_on_next_save", from: actor).present?

        results = actor.cast_spell(spell, targets: [ target ].compact, disadvantage_on_save:)

        record(actor:, round:, turn:, results: TurnRecord.serialize_results(results), action: {
          type: :cast_spell,
          spell_id: spell.id,
          spell_slug: spell.slug,
          spell_name: spell.name,
          target_type: payload["target"]
        })
      end

      # The turn's log entry; the header (round, turn, actor) is built in Combat::TurnRecord.for.
      def record(actor:, round:, turn:, **entry)
        TurnRecord.for(actor:, party: @encounter.party_for(actor), round:, turn:, **entry)
      end
  end
end
