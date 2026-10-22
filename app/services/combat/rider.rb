module Combat
  # A rider (glossary: Rider) in Combat::Simulator's round_log: the feature it comes from, the effect it
  # applied, if any (a maneuver's die, serialized like any effect result), and the kinds of the statuses it
  # applied (Combat::Status: the maneuver's statuses, Eldritch Strike's disadvantage_on_next_save). #to_h is the
  # logged hash, always in this order: feature_slug, feature_name, the effect's keys, then statuses, left out when it applied none.
  #
  # The attack action logs the riders chosen for it with only the feature (Rider.for(feature:).to_h).
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
