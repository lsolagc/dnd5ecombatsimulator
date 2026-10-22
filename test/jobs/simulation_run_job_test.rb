require "test_helper"
require "turbo/broadcastable/test_helper"
require "minitest/mock"

class SimulationRunJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper

  setup do
    @batch = SimulationBatch.create!(party_one_ids: [ player_characters(:aragorn).id, player_characters(:elora).id ],
                                     party_two_ids: [ player_characters(:aragorn_copy).id ], requested_count: 3)
  end

  test "runs one simulation with its own seed and metrics, and only the last one completes the batch" do
    2.times { SimulationRunJob.perform_now(@batch) }

    assert @batch.reload.running?
    assert_not_nil @batch.started_at

    SimulationRunJob.perform_now(@batch)

    assert @batch.reload.completed?
    assert_equal 3, @batch.simulation_runs.count
    @batch.simulation_runs.each do |run|
      assert_kind_of Integer, run.seed
      assert run.elapsed_ms.positive?
      assert_includes %w[ victory draw max_rounds_reached ], run.outcome
    end
  end

  test "a run starts each combatant at the experiment's HP, not the sheet's maximum" do
    aragorn, copy = player_characters(:aragorn), player_characters(:aragorn_copy)
    batch = SimulationBatch.create!(party_one_ids: [ aragorn.id ], party_two_ids: [ copy.id ], seed: 77,
                                    combatant_settings: { copy.id.to_s => SimulationBatch.blueprint_settings(copy).merge("current_hit_points" => 3) })

    SimulationRunJob.perform_now(batch)

    simulate = ->(**hit_points) { Combat::Simulator.new(party_one: batch.party_one, party_two: batch.party_two, seed: 77, **hit_points).call.as_json }
    assert_equal simulate.(hit_points: { copy.id => 3 }), batch.simulation_runs.sole.result
    assert_not_equal simulate.call, batch.simulation_runs.sole.result, "the seed must make the starting HP show"
  end

  test "a seeded batch reproduces the simulator's result for that seed" do
    seeded = SimulationBatch.create!(party_one_ids: @batch.party_one_ids, party_two_ids: @batch.party_two_ids, seed: 77, requested_count: 50)

    SimulationRunJob.perform_now(seeded)

    run = seeded.simulation_runs.sole
    expected = Combat::Simulator.new(party_one: seeded.party_one, party_two: seeded.party_two, seed: 77).call
    assert_equal 77, run.seed
    assert_equal expected.as_json, run.result
    assert seeded.reload.completed?
  end

  test "cancelling mid-simulation aborts it without saving it" do
    checks = 0
    @batch.define_singleton_method(:cancelled_in_database?) do
      checks += 1
      update_columns(status: "cancelled") if checks == 2
      cancelled?
    end

    SimulationRunJob.perform_now(@batch)

    assert @batch.reload.cancelled?
    assert_equal 0, @batch.simulation_runs.count, "the aborted simulation must not be saved"
    assert_equal 2, checks, "the simulator checks before every round and stops at the first cancellation"
  end

  test "a simulation cancelled during its last round is dropped, not saved" do
    cancelled = false
    @batch.define_singleton_method(:cancelled_in_database?) { cancelled }
    result = Combat::Simulator.new(party_one: @batch.party_one, party_two: @batch.party_two, seed: 1).call
    # A simulation that gets through its last between-rounds check just before the batch is cancelled.
    finishing = Object.new
    finishing.define_singleton_method(:call) { cancelled = true; result }

    Combat::Simulator.stub(:new, ->(**) { finishing }) { SimulationRunJob.perform_now(@batch) }

    assert cancelled
    assert_equal 0, @batch.simulation_runs.count
  end

  test "a job of a cancelled or failed batch does nothing" do
    @batch.cancel!
    SimulationRunJob.perform_now(@batch)

    assert @batch.reload.cancelled?
    assert_nil @batch.started_at
    assert_equal 0, @batch.simulation_runs.count
  end

  test "completes the batch only once, even if two workers finish together" do
    2.times { @batch.simulation_runs.create!(seed: 1, elapsed_ms: 1, outcome: "draw", result: {}) }
    @batch.start!
    @batch.simulation_runs.create!(seed: 1, elapsed_ms: 1, outcome: "draw", result: {})

    assert @batch.complete_if_done!
    assert_not @batch.complete_if_done!
  end

  test "a simulation that raises fails the batch and stops its other jobs" do
    @batch.update_column(:combatant_settings, @batch.combatant_settings.transform_values { |settings| settings.merge("damage_dice" => "oops") })

    assert_raises(ArgumentError) { SimulationRunJob.perform_now(@batch) }

    assert @batch.reload.failed?
    assert_match(/dice must be formatted/, @batch.error_message)
    SimulationRunJob.perform_now(@batch)
    assert_equal 0, @batch.simulation_runs.count
  end

  test "pushes progress to the experiment page, throttled, and always pushes the final result" do
    freeze_time # each simulation here takes longer than the throttle window

    3.times { SimulationRunJob.perform_now(@batch) }

    # The second simulation fell inside the throttle window; the third completed the batch, which always goes out.
    pushes = capture_turbo_stream_broadcasts(@batch)
    assert_equal 2, pushes.size
    assert_includes pushes.last.to_html, "Resultado"
    assert @batch.reload.completed?
  end

  test "the progress push morphs the status frame in place" do
    SimulationRunJob.perform_now(@batch)

    stream = capture_turbo_stream_broadcasts(@batch).sole
    assert_equal [ "update", "batch_status", "morph" ], [ stream["action"], stream["target"], stream["method"] ]
    assert_match %r{1<span class="sim-hero__total"> / 3 simulações finalizadas}, stream.to_html
  end

  test "the run plays and logs the gambits copied at creation, whatever happens to the character's rules before it runs" do
    aragorn = player_characters(:aragorn)
    edits = {
      "edited" => -> { aragorn.gambits.each { |rule| rule.update!(target: :enemy, action_kind: :attack, class_feature: nil) } },
      "deleted" => -> { aragorn.gambits.destroy_all },
      "disabled" => -> { aragorn.gambits.each { |rule| rule.update!(enabled: false) } }
    }

    edits.each do |name, edit|
      aragorn.gambits.reload.destroy_all
      aragorn.gambits.create!(position: 1, target: :self, condition: :any, action_kind: :class_feature, class_feature: class_features(:fighter_second_wind))
      batch = SimulationBatch.create!(party_one_ids: [ aragorn.id ], party_two_ids: [ player_characters(:aragorn_copy).id ], seed: 1)
      edit.call
      aragorn.gambits.reload

      SimulationRunJob.perform_now(batch)

      result = batch.simulation_runs.sole.result
      first_turn = result["round_log"].flat_map { |round| round["turns"] }
        .find { |turn| turn["actor_id"] == aragorn.id && turn.dig("action", "type") != "turn_passive" }
      assert_equal [ "second-wind", { "position" => 1, "rule" => "Self: qualquer → Second Wind" } ],
                   [ first_turn.dig("action", "feature_slug"), first_turn["gambit"] ], "#{name}: the run must follow the copy"
      assert_equal [ "gambits", [ "Self: qualquer → Second Wind" ] ],
                   JSON.parse(batch.logs_json).dig("header", "parties", "party_one", 0, "gambits").then { |entry| [ entry["mode"], entry["rules"].pluck("rule") ] }, name
    end
  end

  test "editing the gambits after a run leaves its logs unchanged" do
    aragorn = player_characters(:aragorn)
    rule = aragorn.gambits.create!(position: 1, target: :enemy, condition: :any, action_kind: :attack)
    second_wind = class_features(:fighter_second_wind)
    aragorn.gambits.create!(position: 2, target: :self, condition: :hp_below, condition_value: 50, action_kind: :class_feature, class_feature: second_wind)
    batch = SimulationBatch.create!(party_one_ids: [ aragorn.id ], party_two_ids: [ player_characters(:aragorn_copy).id ], seed: 1)
    SimulationRunJob.perform_now(batch)
    before = JSON.parse(batch.reload.logs_json)

    rule.update!(condition: :lowest_hp, enabled: false)
    second_wind.update!(name: "Fôlego Renomeado") # the log keeps the action's name from the copy
    aragorn.gambits.create!(position: 3, target: :self, condition: :any, action_kind: :class_feature, class_feature: second_wind)

    assert_equal before, JSON.parse(SimulationBatch.find(batch.id).logs_json)
    rules = before.dig("header", "parties", "party_one", 0, "gambits", "rules")
    assert_equal [ "Inimigo: qualquer → Ataque", "Self: HP < 50% → Second Wind" ], rules.pluck("rule")
    assert_equal [ "Ataque", "Second Wind" ], rules.pluck("action")
  end
end
