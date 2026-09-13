class AddSubclassMarkerToClassFeatures < ActiveRecord::Migration[8.0]
  def change
    add_reference :class_features, :subclass_marker, null: true, foreign_key: { to_table: :class_features }
  end
end
