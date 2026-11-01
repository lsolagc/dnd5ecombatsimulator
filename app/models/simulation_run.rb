class SimulationRun < ApplicationRecord
  belongs_to :simulation_batch

  # Batch metrics from a Combat::Simulator round_log: .okf/architecture/simulation-batches.md (Metrics)
  def self.metrics(round_log)
    effects_by_round = round_log.map do |round|
      round[:turns].flat_map { |turn| turn[:results].flat_map { |result| [ result, *result[:riders] ] } }
    end

    heals = effects_by_round.flatten.select { |effect| effect[:kind] == :heal }
    healing_done = heals.sum { |heal| heal[:hp_after] - heal[:hp_before] }

    {
      healing_done:,
      healing_wasted: heals.sum { |heal| heal[:amount] } - healing_done,
      max_round_damage: effects_by_round.map { |effects| effects.sum { |effect| damage_dealt(effect) } }.max || 0
    }
  end

  def self.damage_dealt(effect)
    effect[:kind].in?([ :attack, :damage ]) ? effect[:hp_before] - effect[:hp_after] : 0
  end
  private_class_method :damage_dealt
end
