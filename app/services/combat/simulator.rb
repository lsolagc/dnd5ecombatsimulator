module Combat
  # The combat orchestrator, one seeded and repeatable fight of two parties of sheets (glossary: Simulator): .okf/architecture/combat-simulator.md
  class Simulator
    DEFAULT_MAX_ROUNDS = 20

    # Raised from #call when abort_if returns true; the partial simulation is discarded.
    class Aborted < StandardError; end

    # Set by #call: the fight (its participants, for a caller to inspect afterwards) and the RNG of the
    # random choices (picks and targets; the dice roll on the global Random, pinned to the seed in #call).
    attr_reader :encounter, :rng

    # Every parameter, and the combatant ids that key hit_points and gambits: .okf/architecture/combat-simulator.md (Contract)
    def initialize(party_one:, party_two:, seed: nil, max_rounds: DEFAULT_MAX_ROUNDS, abort_if: nil, gambits: nil, hit_points: {})
      raise ArgumentError, "Both parties must be Arrays" unless party_one.is_a?(Array) && party_two.is_a?(Array)
      raise ArgumentError, "Parties must not be empty" if party_one.empty? || party_two.empty?

      @sheets = [ party_one, party_two ]
      @hit_points = hit_points.to_h.transform_keys(&:to_i)
      @seed = seed
      @abort_if = abort_if
      @gambit_settings = gambits
      @max_rounds = Integer(max_rounds)
      raise ArgumentError, "max_rounds must be greater than 0" if @max_rounds <= 0

      @rng = @seed.nil? ? Random.new : Random.new(@seed)
      @round_log = []
    end

    # Runs the fight and returns the result hash; a block gets the encounter once initiative is rolled. One fight per
    # instance. See .okf/architecture/combat-simulator.md (Contract)
    def call
      with_seed do
        build_encounter
        @encounter.initiative_order = roll_initiative
        yield @encounter if block_given?

        round_number = 0

        while round_number < @max_rounds
          break if @encounter.over?
          raise Aborted if @abort_if&.call

          round_number += 1
          turns = play_round(round_number)
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
      def build_encounter
        party_one, party_two = @sheets.map do |sheets|
          sheets.map { |sheet| Participant.new(sheet, hit_points: @hit_points[sheet.combatant.id]) }
        end
        @encounter = Encounter.new(party_one:, party_two:)
        @executor = TurnExecutor.new(encounter: @encounter, rng: @rng, policy: GambitPolicy.new(encounter: @encounter, gambits: @gambit_settings))
      end

      # One d20 per combatant, in party order (the RNG sequence), sorted by total with ties kept in that
      # order. The rolls stay in @initiative for the result.
      def roll_initiative
        initiative_entries = @encounter.participants.each_with_index.map do |combatant, index|
          roll = Dice.d20(modifier: combatant.initiative)
          { combatant:, natural: roll.natural, total: roll.total, tie_breaker: index }
        end

        @initiative = initiative_entries.sort_by { |entry| [ -entry[:total], entry[:tie_breaker] ] }
        @initiative.map { |entry| entry[:combatant] }
      end

      # Every actor in initiative order: its turn starts (dead or alive), then a living one's turn passives
      # and decisions, while the fight lasts.
      def play_round(round_number)
        turns = []

        @encounter.initiative_order.each_with_index do |actor, index|
          turn = index + 1
          @encounter.start_turn(actor)
          next if actor.dead?
          break if @encounter.over?

          start_log = turn_passive_log(actor:, trigger: :turn_start, round: round_number, turn:)
          turns << start_log if start_log
          next if actor.dead?

          turns.concat(@executor.take_turn(actor, round: round_number, turn:))

          end_log = turn_passive_log(actor:, trigger: :turn_end, round: round_number, turn:)
          turns << end_log if end_log
        end

        turns
      end

      def turn_passive_log(actor:, trigger:, round:, turn:)
        results = actor.apply_turn_passives!(trigger: trigger.to_s)
        return nil if results.empty?

        TurnRecord.for(actor:, party: @encounter.party_for(actor), round:, turn:,
                       action: { type: :turn_passive, trigger: trigger.to_s }, results: TurnRecord.serialize_results(results))
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
end
