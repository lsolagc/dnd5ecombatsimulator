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
    assert_equal({ "current_hit_points" => aragorn.max_hit_points, "armor_class" => 16, "attack_bonus" => aragorn.combatant.attack_bonus,
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
    assert_equal({ "current_hit_points" => 5, "armor_class" => 18, "attack_bonus" => 4, "damage_dice" => "1d8", "damage_type" => "slashing",
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
    assert_equal 3, fighter.current_hit_points
    assert_equal 20, fighter.armor_class
    assert_equal 9, fighter.attack_bonus
    assert_equal "2d6", fighter.damage_dice
    assert_equal "fire", fighter.damage_type
    assert fighter.immune_to?(damage_type: :cold)
    assert fighter.vulnerable_to?(damage_type: :fire)
    assert_not fighter.resistant_to?(damage_type: :cold)

    aragorn.reload
    assert_equal 16, aragorn.armor_class
    assert_not aragorn.immune_to?(damage_type: :cold)
  end

  test "a rerun copies the combatants, their settings, count and seed into a new experiment" do
    record = batch(seed: 7)
    record.save!

    copy = record.rerun
    assert copy.new_record?
    assert_equal [ record.party_one_ids, record.party_two_ids, record.combatant_settings, 1, 7 ],
                 [ copy.party_one_ids, copy.party_two_ids, copy.combatant_settings, copy.requested_count, copy.seed ]
  end

  private

    # A form entry carrying Aragorn-like defaults, overridden per test.
    def form_entry(side, **overrides)
      { "side" => side, "current_hit_points" => "8", "armor_class" => "16", "attack_bonus" => "4", "damage_dice" => "1d8",
        "damage_type" => "slashing", "defenses" => {} }.merge(overrides.transform_keys(&:to_s))
    end
end
