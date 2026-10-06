require "test_helper"

class SimulationRunTest < ActiveSupport::TestCase
  test "metrics split healing into restored and wasted and keep the worst round's damage" do
    round_log = [
      { round: 1, turns: [
        { results: [ { kind: :attack, hp_before: 20, hp_after: 12 }, { kind: :attack, hp_before: 12, hp_after: 12 } ] },
        # Heal of 10 on a target at 15/18: 3 restored, 7 wasted.
        { results: [ { kind: :heal, amount: 10, hp_before: 15, hp_after: 18 } ] }
      ] },
      { round: 2, turns: [
        # A maneuver rider rides on the attack entry and counts as damage in the same round.
        { results: [ { kind: :attack, hp_before: 18, hp_after: 10, rider: { kind: :damage, amount: 5, hp_before: 10, hp_after: 5 } } ] },
        { results: [ { kind: :damage, amount: 9, hp_before: 4, hp_after: 0 } ] },
        { results: [ { kind: :heal, amount: 4, hp_before: 1, hp_after: 5 } ] }
      ] }
    ]

    assert_equal({ healing_done: 7, healing_wasted: 7, max_round_damage: 17 }, SimulationRun.metrics(round_log))
  end

  test "metrics of a combat that never started are zero" do
    assert_equal({ healing_done: 0, healing_wasted: 0, max_round_damage: 0 }, SimulationRun.metrics([]))
  end
end
