require "test_helper"

class SimulationBatchTest < ActiveSupport::TestCase
  def batch(**attributes)
    SimulationBatch.new(party_one_ids: [ player_characters(:aragorn).id ], party_two_ids: [ player_characters(:merlin).id ], requested_count: 10, **attributes)
  end

  test "is valid with one character on each side" do
    assert batch.valid?
  end

  test "requires combatants on both sides" do
    assert_not batch(party_two_ids: []).valid?
    assert_not batch(party_one_ids: []).valid?
  end

  test "rejects a character on both sides" do
    shared = player_characters(:aragorn).id
    record = batch(party_one_ids: [ shared ], party_two_ids: [ shared, player_characters(:merlin).id ])

    assert_not record.valid?
    assert_includes record.errors[:base], "Um personagem não pode estar nos dois lados"
  end

  test "rejects unknown characters" do
    assert_not batch(party_two_ids: [ -1 ]).valid?
  end

  test "allows several characters per side" do
    assert batch(party_one_ids: [ player_characters(:aragorn).id, player_characters(:elora).id ]).valid?
  end

  test "caps the batch at 1000 simulations" do
    assert batch(requested_count: 1000).valid?
    assert_not batch(requested_count: 1001).valid?
    assert_not batch(requested_count: 0).valid?
  end

  test "a seed forces exactly one simulation" do
    record = batch(requested_count: 500, seed: 42)

    assert record.valid?
    assert_equal 1, record.requested_count
  end

  test "loads fresh character instances on every call, since the simulator mutates them" do
    record = batch

    assert_not_same record.party_one.first, record.party_one.first
    assert_not_same record.party_two.first, record.party_two.first
  end

  test "sees a cancellation made through another instance" do
    record = batch(status: "running")
    record.save!
    SimulationBatch.find(record.id).cancel!

    assert record.running?, "the in-memory copy is stale"
    assert record.cancelled_in_database?
  end

  test "sees a cancellation from another process even under a job's query cache" do
    record = batch(status: "running")
    record.save!

    # Jobs run with the query cache on, and the web process's UPDATE doesn't clear this connection's cache.
    ActiveRecord::Base.cache do
      assert_not record.cancelled_in_database?
      ActiveRecord::Base.connection.raw_connection.exec("UPDATE simulation_batches SET status = 'cancelled' WHERE id = #{record.id}")
      assert record.cancelled_in_database?
    end
  end

  test "snapshots each character's sheet as its experiment settings" do
    record = batch
    record.validate

    aragorn = player_characters(:aragorn)
    assert_equal({ "name" => "Aragorn", "current_hit_points" => aragorn.max_hit_points, "armor_class" => 16, "attack_bonus" => aragorn.combatant.attack_bonus,
                   "damage_dice" => aragorn.combatant.damage_dice, "damage_type" => aragorn.combatant.damage_type, "defenses" => {} },
                 record.combatant_settings[aragorn.id.to_s])
    assert_equal [ aragorn.id, player_characters(:merlin).id ].map(&:to_s).sort, record.combatant_settings.keys.sort
  end

  test "reads sides and settings from the experiment form" do
    aragorn, merlin = player_characters(:aragorn), player_characters(:merlin)
    record = SimulationBatch.new(requested_count: 3, combatants: {
      aragorn.id.to_s => form_entry("party_one", current_hit_points: "5", armor_class: "18", defenses: { "fire" => "R", "cold" => "" }),
      merlin.id.to_s => form_entry("party_two")
    })

    assert record.valid?, record.errors.full_messages.to_sentence
    assert_equal [ aragorn.id ], record.party_one_ids
    assert_equal [ merlin.id ], record.party_two_ids
    assert_equal({ "name" => "Aragorn", "current_hit_points" => 5, "armor_class" => 18, "attack_bonus" => 4, "damage_dice" => "1d8", "damage_type" => "slashing",
                   "defenses" => { "fire" => "R" } }, record.combatant_settings[aragorn.id.to_s])
  end

  test "rejects experiment settings the simulator cannot run" do
    aragorn = player_characters(:aragorn)
    record = SimulationBatch.new(requested_count: 3, combatants: {
      aragorn.id.to_s => form_entry("party_one", current_hit_points: (aragorn.max_hit_points + 1).to_s, armor_class: "-1", attack_bonus: "x",
                                    damage_dice: "d8", damage_type: "sonic", defenses: { "fire" => "X" }),
      player_characters(:merlin).id.to_s => form_entry("party_two")
    })

    assert_not record.valid?
    assert_equal [ "Aragorn: HP inicial deve estar entre 1 e #{aragorn.max_hit_points}", "Aragorn: CA deve ser um número inteiro a partir de 0",
                   "Aragorn: bônus de ataque deve ser um número inteiro", "Aragorn: dano deve ter o formato 1d8",
                   "Aragorn: tipo de dano inválido", "Aragorn: defesas inválidas" ], record.errors[:base]
  end

  test "applies the settings to in-memory combatants and leaves the sheet untouched" do
    aragorn = player_characters(:aragorn)
    record = SimulationBatch.create!(requested_count: 1, combatants: {
      aragorn.id.to_s => form_entry("party_one", current_hit_points: "3", armor_class: "20", attack_bonus: "9", damage_dice: "2d6",
                                    damage_type: "fire", defenses: { "cold" => "I", "fire" => "V" }),
      player_characters(:merlin).id.to_s => form_entry("party_two")
    })

    fighter = record.party_one.sole
    assert_equal 3, record.hit_points[aragorn.id], "the starting HP goes to the simulator, not the sheet"
    assert_equal 20, fighter.armor_class
    assert_equal 9, fighter.attack_bonus
    assert_equal "2d6", fighter.damage_dice
    assert_equal "fire", fighter.damage_type
    assert_equal({ "cold" => "I", "fire" => "V" }, fighter.defenses.to_h)

    assert_raises(ActiveRecord::ReadOnlyRecord) { fighter.save! }
    assert_raises(ActiveRecord::ReadOnlyRecord) { fighter.combatant.save! }

    aragorn.reload
    assert_equal 16, aragorn.armor_class
    assert_not aragorn.defenses.immune_to?(:cold)
  end

  test "a rerun copies the combatants, their settings, count and seed into a new experiment" do
    record = batch(seed: 7)
    record.save!

    copy = record.rerun
    assert copy.new_record?
    assert_equal [ record.party_one_ids, record.party_two_ids, record.combatant_settings.transform_values { |settings| settings.except("name") }, 1, 7 ],
                 [ copy.party_one_ids, copy.party_two_ids, copy.combatant_settings, copy.requested_count, copy.seed ]
  end

  test "copies every character's gambits, enabled or not and in priority order, when the batch is created" do
    aragorn = player_characters(:aragorn)
    aragorn.gambits.create!(position: 2, target: :enemy, condition: :hp_below, condition_value: 50, action_kind: :attack, enabled: false)
    aragorn.gambits.create!(position: 1, target: :self, condition: :any, action_kind: :class_feature, class_feature: class_features(:fighter_second_wind))

    record = batch
    record.save!

    assert_equal [ aragorn.id, player_characters(:merlin).id ].map(&:to_s).sort, record.gambit_settings.keys.sort
    assert_equal [], record.gambit_settings[player_characters(:merlin).id.to_s]
    assert_equal [
      { "position" => 1, "enabled" => true, "target" => "self", "condition" => "any", "condition_value" => nil, "action_kind" => "class_feature",
        "class_feature_id" => class_features(:fighter_second_wind).id, "spell_id" => nil,
        "target_label" => "Self", "condition_label" => "qualquer", "action_label" => "Second Wind", "label" => "Self: qualquer → Second Wind" },
      { "position" => 2, "enabled" => false, "target" => "enemy", "condition" => "hp_below", "condition_value" => 50, "action_kind" => "attack",
        "class_feature_id" => nil, "spell_id" => nil,
        "target_label" => "Inimigo", "condition_label" => "HP < 50%", "action_label" => "Ataque", "label" => "Inimigo: HP < 50% → Ataque" }
    ], SimulationBatch.find(record.id).gambit_settings[aragorn.id.to_s]
  end

  test "the gambits copy is never rewritten by later saves, even after the character's rules change" do
    aragorn = player_characters(:aragorn)
    rule = aragorn.gambits.create!(position: 1, target: :enemy, condition: :any, action_kind: :attack)
    record = batch
    record.save!
    copied = record.gambit_settings

    rule.update!(condition: :lowest_hp)
    aragorn.gambits.create!(position: 2, target: :self, condition: :any, action_kind: :class_feature, class_feature: class_features(:fighter_second_wind))
    merlin = player_characters(:merlin) # no rules at creation: its empty copy must stay empty too
    merlin.gambits.create!(position: 1, target: :enemy, condition: :any, action_kind: :attack)
    SimulationBatch.find(record.id).update!(status: "running")
    SimulationBatch.find(record.id).cancel!

    assert_equal copied, SimulationBatch.find(record.id).gambit_settings
    assert_equal [ "Inimigo: qualquer → Ataque" ], copied[aragorn.id.to_s].pluck("label")
    assert_equal [], SimulationBatch.find(record.id).gambit_settings[merlin.id.to_s]
  end

  test "a rerun does not copy the gambits: the new experiment takes the character's current rules" do
    aragorn = player_characters(:aragorn)
    rule = aragorn.gambits.create!(position: 1, target: :enemy, condition: :any, action_kind: :attack)
    record = batch
    record.save!
    rule.update!(enabled: false)

    copy = record.rerun
    assert_equal({}, copy.gambit_settings)

    copy.save!
    assert_equal [ false ], copy.gambit_settings[aragorn.id.to_s].pluck("enabled")
    assert_equal [ true ], record.reload.gambit_settings[aragorn.id.to_s].pluck("enabled")
  end

  test "the log is one JSON: a header with the batch and each side's combatants, then every simulation in order" do
    aragorn, merlin = player_characters(:aragorn), player_characters(:merlin)
    aragorn.gambits.create!(position: 1, target: :enemy, condition: :any, action_kind: :attack)
    record = batch(requested_count: 2)
    record.save!
    2.times { SimulationRunJob.perform_now(record) }

    log = JSON.parse(record.reload.logs_json)
    assert_equal JSON.pretty_generate(log), record.logs_json, "formatted for reading"

    assert_equal %w[ header simulations ], log.keys
    assert_equal %w[ batch parties ], log["header"].keys
    assert_equal %w[ id status requested_count seed summary ], log.dig("header", "batch").keys
    assert_equal [ record.id, "completed", 2, nil, 2 ], log.dig("header", "batch").values_at("id", "status", "requested_count", "seed").push(log.dig("header", "batch", "summary", "total"))
    assert_equal %w[ party_one party_two ], log.dig("header", "parties").keys
    aragorn_entry = log.dig("header", "parties", "party_one").sole
    assert_equal %w[ id name settings gambits ], aragorn_entry.keys
    assert_equal [ aragorn.id, "Aragorn", record.combatant_settings[aragorn.id.to_s].except("name") ], aragorn_entry.values_at("id", "name", "settings")
    assert_equal({ "mode" => "gambits", "rules" => [
      { "position" => 1, "enabled" => true, "target" => "Inimigo", "condition" => "qualquer", "action" => "Ataque", "rule" => "Inimigo: qualquer → Ataque" }
    ] }, aragorn_entry["gambits"])
    assert_equal [ merlin.id, merlin.name, { "mode" => "aleatório", "rules" => [] } ],
                 log.dig("header", "parties", "party_two").sole.values_at("id", "name", "gambits")

    simulations = log["simulations"]
    assert_equal [ 1, 2 ], simulations.pluck("simulation")
    assert_equal record.simulation_runs.map(&:seed), simulations.pluck("seed")
    simulations.each do |simulation|
      assert_equal %w[ simulation seed elapsed_ms outcome winning_party total_rounds draw initiative round_log ], simulation.keys
    end
  end

  # The golden files hold the simulator's results in the order it builds them, every kind of entry included.
  test "the log rebuilds every turn in the simulator's order after jsonb, unknown keys last" do
    results = CombatRegression::COMPOSITIONS.keys.flat_map { |name| YAML.load_file(CombatRegression.golden_path(name), permitted_classes: [ Symbol ]).values }
    assert_operator results.size, :>=, 60
    legacy = results.first[:round_log].first[:turns].first # a key from an older run: one letter, so jsonb puts it first
    legacy[:a] = 1
    legacy[:action] = legacy[:action].merge(a: 1)
    record = batch(requested_count: results.size)
    record.save!
    results.each { |result| record.simulation_runs.create!(seed: 1, elapsed_ms: 1, outcome: result[:outcome], result:) }

    stored = record.simulation_runs.map(&:result)
    simulations = JSON.parse(record.logs_json)["simulations"]

    expected = JSON.parse(results.to_json)
    assert_not_equal expected.pluck("round_log").to_json, stored.pluck("round_log").to_json, "jsonb must have shuffled the keys"
    assert_equal expected.pluck("round_log").to_json, simulations.pluck("round_log").to_json
    assert_equal expected.pluck("initiative").to_json, simulations.pluck("initiative").to_json
    assert_equal "a", stored.first.dig("round_log", 0, "turns", 0).keys.first
    turn = simulations.first.dig("round_log", 0, "turns", 0)
    assert_equal [ "a", "a" ], [ turn.keys.last, turn["action"].keys.last ]
  end

  test "the log keeps each combatant's name from the batch's creation; a rerun takes the current one" do
    aragorn = player_characters(:aragorn)
    record = batch
    record.save!
    aragorn.update!(name: "Aragorn Renomeado")
    record.cancel!

    assert_equal "Aragorn", JSON.parse(SimulationBatch.find(record.id).logs_json).dig("header", "parties", "party_one", 0, "name")

    copy = record.rerun
    copy.save!
    assert_equal "Aragorn Renomeado", JSON.parse(copy.logs_json).dig("header", "parties", "party_one", 0, "name")
  end

  test "a batch from before names were frozen never gets today's name on a later save" do
    record = batch
    record.save!
    record.update_columns(combatant_settings: record.combatant_settings.transform_values { |settings| settings.except("name") })
    SimulationBatch.find(record.id).cancel!

    assert_nil JSON.parse(SimulationBatch.find(record.id).logs_json).dig("header", "parties", "party_one", 0, "name")
  end

  private

    # A form entry carrying Aragorn-like defaults, overridden per test.
    def form_entry(side, **overrides)
      { "side" => side, "current_hit_points" => "8", "armor_class" => "16", "attack_bonus" => "4", "damage_dice" => "1d8",
        "damage_type" => "slashing", "defenses" => {} }.merge(overrides.transform_keys(&:to_s))
    end
end
