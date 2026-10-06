class CreateSimulationBatches < ActiveRecord::Migration[8.0]
  def change
    create_table :simulation_batches do |t|
      t.bigint :party_one_ids, array: true, null: false, default: []
      t.bigint :party_two_ids, array: true, null: false, default: []
      t.jsonb :combatant_settings, null: false, default: {}
      t.integer :requested_count, null: false
      t.bigint :seed
      t.string :status, null: false, default: "pending"
      t.text :error_message
      t.datetime :started_at
      t.datetime :progress_broadcast_at
      t.timestamps
    end

    create_table :simulation_runs do |t|
      t.references :simulation_batch, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :seed, null: false
      t.float :elapsed_ms, null: false
      t.string :winning_party
      t.string :outcome, null: false
      t.integer :healing_done, null: false, default: 0
      t.integer :healing_wasted, null: false, default: 0
      t.integer :max_round_damage, null: false, default: 0
      t.jsonb :result, null: false
      t.timestamps
    end
  end
end
