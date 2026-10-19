module Combat
  # A status (glossary: Status) on the Combat::Participant that carries it: its kind, the participant who
  # applied it (source) and when it ends by itself (ends: "source_turn_start", at the start of the source's
  # next turn; nil, only when consumed). A carrier holds at most one per kind and source
  # (Participant#add_status renews it).
  class Status < Data.define(:kind, :source, :ends)
    # The one vocabulary of statuses: the payload's statuses items and the rider's applies are validated
    # against it (ClassFeatureUnlock::EFFECT_KINDS).
    # next_attack_advantage: the next weapon attack against the carrier by anyone but the source has advantage
    # (Distracting Strike). disadvantage_on_next_save: the carrier's next save against the source's spell has
    # disadvantage (Eldritch Strike).
    KINDS = %w[next_attack_advantage disadvantage_on_next_save].freeze
    ENDS = %w[source_turn_start].freeze

    def initialize(kind:, source:, ends: nil)
      raise ArgumentError, "Unsupported status kind: #{kind.inspect}" unless KINDS.include?(kind)
      raise ArgumentError, "Unsupported status end: #{ends.inspect}" unless ends.nil? || ENDS.include?(ends)

      super
    end
  end
end
