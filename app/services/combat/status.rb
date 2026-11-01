module Combat
  # A status (glossary: Status) on the Combat::Participant that carries it: .okf/architecture/combat-simulator.md (Statuses)
  class Status < Data.define(:kind, :source, :ends)
    # The one vocabulary of statuses (ClassFeatureUnlock::EFFECT_KINDS validates against it): .okf/architecture/combat-simulator.md (Statuses)
    KINDS = %w[next_attack_advantage disadvantage_on_next_save].freeze
    ENDS = %w[source_turn_start].freeze

    def initialize(kind:, source:, ends: nil)
      raise ArgumentError, "Unsupported status kind: #{kind.inspect}" unless KINDS.include?(kind)
      raise ArgumentError, "Unsupported status end: #{ends.inspect}" unless ends.nil? || ENDS.include?(ends)

      super
    end
  end
end
