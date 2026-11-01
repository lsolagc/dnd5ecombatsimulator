module Combat
  # One entry of a round's turns in the round_log (glossary: Turn record): .okf/architecture/combat-simulator.md (Turn resolution)
  TurnRecord = Data.define(:round, :turn, :actor_id, :actor_name, :actor_party, :action, :results, :gambit, :extra, :bonus) do
    def self.for(actor:, party:, round:, turn:, action:, results: [], **flags)
      new(round:, turn:, actor_id: actor.id, actor_name: actor.name, actor_party: party, action:, results:, **flags)
    end

    def initialize(gambit: nil, extra: false, bonus: false, **header)
      super
    end

    # The logged hashes of Combat::EffectExecutor results (a record's results); attack_roll only when the
    # effect made one.
    def self.serialize_results(results)
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

    def to_h = super.reject { |key, value| %i[gambit extra bonus].include?(key) && !value }
  end
end
