# A batch's download: one pretty JSON with the batch's setup (each combatant's name, settings and gambits as
# frozen at creation) in a header, then every simulation in order. jsonb doesn't keep key order, so the
# hashes are rebuilt here in reading order (SIMULATION_LOG_ORDER, down to every turn); keys an older run still
# carries go after the known ones.
class SimulationBatch::LogExport
  # The order of a simulation's keys in the download, nested: key => the order of its value's keys (an array's
  # items each), nil to keep the value as stored. Below the top, the order Combat::Simulator builds them in
  # (Combat::TurnRecord, the attack and effect entries, Combat::Rider); one list serves every kind of an entry
  # (a weapon attack, an effect; each action type), each kind keeping its own keys' relative order.
  ROLL_OUTCOME_LOG_ORDER = %w[ expression resolved_expression dice rolls modifiers total ].index_with(nil).freeze
  ATTACK_ROLL_LOG_ORDER = Combat::EffectExecutor::AttackRoll.members.map(&:to_s).index_with(nil).freeze
  EFFECT_LOG_ORDER = %w[ kind applied amount hp_before hp_after roll_outcome attack_roll ].index_with(nil)
    .merge("roll_outcome" => ROLL_OUTCOME_LOG_ORDER, "attack_roll" => ATTACK_ROLL_LOG_ORDER).freeze
  RIDER_LOG_ORDER = { "feature_slug" => nil, "feature_name" => nil, **EFFECT_LOG_ORDER, "statuses" => nil }.freeze
  RESULT_LOG_ORDER = { "kind" => nil, "target_id" => nil, "target_name" => nil, "advantage" => nil, "riders" => RIDER_LOG_ORDER,
                       **EFFECT_LOG_ORDER.except("kind") }.freeze
  ACTION_LOG_ORDER = %w[ type riders trigger feature_id feature_slug feature_name spell_id spell_slug spell_name target_type ]
    .index_with(nil).merge("riders" => RIDER_LOG_ORDER).freeze
  TURN_LOG_ORDER = Combat::TurnRecord.members.map(&:to_s).index_with(nil)
    .merge("action" => ACTION_LOG_ORDER, "results" => RESULT_LOG_ORDER, "gambit" => %w[ position rule ].index_with(nil)).freeze
  SIMULATION_LOG_ORDER = {
    "outcome" => nil, "winning_party" => nil, "total_rounds" => nil, "draw" => nil,
    "initiative" => %w[ actor_id natural total ].index_with(nil), "round_log" => { "round" => nil, "turns" => TURN_LOG_ORDER }
  }.freeze

  def initialize(batch)
    @batch = batch
  end

  def json
    JSON.pretty_generate(
      "header" => { "batch" => { "id" => @batch.id, "status" => @batch.status, "requested_count" => @batch.requested_count,
                                 "seed" => @batch.seed, "summary" => @batch.summary },
                    "parties" => parties },
      "simulations" => simulations
    )
  end

  private

    def parties
      { "party_one" => @batch.party_one_ids, "party_two" => @batch.party_two_ids }.transform_values do |ids|
        ids.map do |id|
          settings = @batch.combatant_settings.fetch(id.to_s)
          { "id" => id, "name" => settings["name"], "settings" => settings.except("name"),
            "gambits" => Gambit.log_section(snapshots: @batch.gambit_settings.fetch(id.to_s, [])) }
        end
      end
    end

    def simulations
      @batch.simulation_runs.map.with_index(1) do |run, index|
        { "simulation" => index, "seed" => run.seed, "elapsed_ms" => run.elapsed_ms }.merge(in_log_order(run.result, SIMULATION_LOG_ORDER))
      end
    end

    # value with its hashes' keys in order's order (see SIMULATION_LOG_ORDER), unknown keys last.
    def in_log_order(value, order)
      case value
      when Array then value.map { |item| in_log_order(item, order) }
      when Hash
        return value unless order

        ((order.keys & value.keys) + (value.keys - order.keys)).index_with { |key| in_log_order(value[key], order[key]) }
      else value
      end
    end
end
