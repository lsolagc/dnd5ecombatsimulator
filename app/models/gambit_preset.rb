# A named copy of a character's gambits, created and overwritten from a character's gambits screen and
# applied to others. Copies go both ways (GambitOwner#copy_gambits_from): no link is kept to any character.
class GambitPreset < ApplicationRecord
  include GambitOwner

  NAME_TAKEN = "Já existe um preset com esse nome"

  normalizes :name, with: ->(name) { name.strip }

  # Case-insensitive, like the unique index on lower(name).
  validates :name, presence: { message: "Dê um nome ao preset" },
                   uniqueness: { case_sensitive: false, message: NAME_TAKEN }
end
