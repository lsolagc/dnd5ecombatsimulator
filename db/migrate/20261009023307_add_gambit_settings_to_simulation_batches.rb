class AddGambitSettingsToSimulationBatches < ActiveRecord::Migration[8.0]
  def change
    add_column :simulation_batches, :gambit_settings, :jsonb, default: {}, null: false
  end
end
