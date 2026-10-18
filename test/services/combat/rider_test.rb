require "test_helper"

class Combat::RiderTest < ActiveSupport::TestCase
  setup do
    @feature = class_features(:fighter_battle_master_maneuver_distracting_strike)
    @effect = { kind: :damage, applied: true, amount: 5, hp_before: 20, hp_after: 15 }
  end

  test "for takes the slug and name from the feature; immutable and equal by value" do
    rider = Combat::Rider.for(feature: @feature)

    assert_equal [ @feature.slug, @feature.name, nil, [] ], [ rider.feature_slug, rider.feature_name, rider.effect, rider.statuses ]
    assert rider.frozen?
    assert_equal rider, Combat::Rider.for(feature: @feature)
  end

  test "to_h: feature, then the effect's keys, then statuses, left out when none applied" do
    assert_equal({ feature_slug: @feature.slug, feature_name: @feature.name }, Combat::Rider.for(feature: @feature).to_h)

    logged = Combat::Rider.for(feature: @feature, effect: @effect, statuses: [ "next_attack_advantage" ]).to_h

    assert_equal %i[feature_slug feature_name kind applied amount hp_before hp_after statuses], logged.keys
    assert_equal [ "next_attack_advantage" ], logged[:statuses]
    assert_equal %i[feature_slug feature_name statuses], Combat::Rider.for(feature: @feature, statuses: [ "disadvantage_on_next_save" ]).to_h.keys
  end
end
