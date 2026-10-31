# Batches used to key their sides, settings and logs by PlayerCharacter id; they are now keyed by Combatant id
# and the old ones can't be read correctly. Their runs go with them (simulation_runs' foreign key cascades).
class DeleteSimulationBatchesKeyedByCharacterId < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM simulation_batches"
  end

  # Irreversible on purpose: the deleted batches are gone; rolling back only lets the schema move back.
  def down
  end
end
