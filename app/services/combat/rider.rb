module Combat
  # A rider (glossary: Rider) in the round_log; #to_h is its logged hash: .okf/architecture/combat-simulator.md (Turn resolution)
  Rider = Data.define(:feature_slug, :feature_name, :effect, :statuses) do
    def self.for(feature:, effect: nil, statuses: [])
      new(feature_slug: feature.slug, feature_name: feature.name, effect:, statuses:)
    end

    def to_h
      logged = { feature_slug:, feature_name:, **effect.to_h }
      statuses.empty? ? logged : logged.merge(statuses:)
    end
  end
end
