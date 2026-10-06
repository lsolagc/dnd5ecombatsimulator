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

  test "a seeded batch reproduces the simulator's result for that seed" do
    seeded = SimulationBatch.create!(party_one_ids: @batch.party_one_ids, party_two_ids: @batch.party_two_ids, seed: 77, requested_count: 50)

    SimulationRunJob.perform_now(seeded)

    run = seeded.simulation_runs.sole
    expected = CombatSimulatorService.new(party_one: seeded.party_one, party_two: seeded.party_two, seed: 77).call
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
    result = CombatSimulatorService.new(party_one: @batch.party_one, party_two: @batch.party_two, seed: 1).call
    # A simulation that gets through its last between-rounds check just before the batch is cancelled.
    finishing = Object.new
    finishing.define_singleton_method(:call) { cancelled = true; result }

    CombatSimulatorService.stub(:new, ->(**) { finishing }) { SimulationRunJob.perform_now(@batch) }

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
end
