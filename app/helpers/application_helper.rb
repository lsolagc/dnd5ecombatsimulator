module ApplicationHelper
  DAMAGE_TYPE_LABELS = {
    "acid" => "Ácido", "cold" => "Frio", "fire" => "Fogo", "force" => "Força", "poison" => "Veneno", "psychic" => "Psíquico",
    "radiant" => "Radiante", "thunder" => "Trovejante", "necrotic" => "Necrótico", "piercing" => "Perfurante",
    "slashing" => "Cortante", "lightning" => "Elétrico", "bludgeoning" => "Concussão"
  }.freeze

  def damage_type_labels
    DAMAGE_TYPE_LABELS
  end
end
