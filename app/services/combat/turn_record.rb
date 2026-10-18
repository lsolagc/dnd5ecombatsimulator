module Combat
  # One entry of a round's turns in CombatSimulatorService's round_log. #to_h is the logged hash, always
  # in member order, without gambit/extra/bonus when absent (a turn passive has no gambit; extra marks
  # Action Surge's extra action, bonus War Magic's attack).
  #
  # action:  the logged action hash (its keys vary by type); results: the effect hashes.
  TurnRecord = Data.define(:round, :turn, :actor_id, :actor_name, :actor_party, :action, :results, :gambit, :extra, :bonus) do
    def self.for(actor:, party:, round:, turn:, action:, results: [], **flags)
      new(round:, turn:, actor_id: actor.id, actor_name: actor.name, actor_party: party, action:, results:, **flags)
    end

    def initialize(gambit: nil, extra: false, bonus: false, **header)
      super
    end

    def to_h = super.reject { |key, value| %i[gambit extra bonus].include?(key) && !value }
  end
end
