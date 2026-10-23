# The ceiling of a gambit list lives only in Gambit::MAX_PER_OWNER; the database keeps the floor.
class RelaxGambitsPositionRange < ActiveRecord::Migration[8.0]
  def change
    remove_check_constraint :gambits, "position BETWEEN 1 AND 6", name: "gambits_position_range"
    add_check_constraint :gambits, "position >= 1", name: "gambits_position_range"
  end
end
