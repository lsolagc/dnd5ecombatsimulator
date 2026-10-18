# One simulation of a batch. A batch enqueues requested_count of these at once, so the
# worker processes (bin/jobs) run its simulations in parallel.
class SimulationRunJob < ApplicationJob
  def perform(batch)
    return if batch.finished?

    batch.start!
    seed = batch.seed || SecureRandom.random_number(2**31)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = CombatSimulatorService.new(
      party_one: batch.party_one, party_two: batch.party_two, seed:, gambits: batch.gambit_settings, hit_points: batch.hit_points,
      abort_if: -> { batch.cancelled_in_database? }
    ).call
    elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000
    # The simulator only checks between rounds: one cancelled during its last round still ends here.
    raise CombatSimulatorService::Aborted if batch.cancelled_in_database?

    batch.simulation_runs.create!(
      seed:, elapsed_ms:, result:,
      winning_party: result[:winning_party], outcome: result[:outcome],
      **SimulationRun.metrics(result[:round_log])
    )
    batch.broadcast_progress(force: batch.complete_if_done!)
  rescue CombatSimulatorService::Aborted
    # Cancelled from the UI: this simulation is dropped, finished ones stay.
  rescue StandardError => error
    batch.fail!(error.message)
    batch.broadcast_progress(force: true)
    raise
  end
end
