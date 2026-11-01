module Combat
  # One action the actor can take this turn (glossary: Action option); its fields: .okf/architecture/combat-simulator.md (Turn resolution)
  ActionOption = Data.define(:type, :class_feature, :spell, :payload, :uses_remaining, :target, :gambit) do
    def initialize(type:, class_feature: nil, spell: nil, payload: nil, uses_remaining: nil, target: nil, gambit: nil)
      super
    end

    def chosen_by_gambit? = !gambit.nil?
    def spell? = type == :cast_spell
    def action_surge? = type == :action_surge
    # A maneuver is not an action of its own: it rides on a normal weapon attack.
    def maneuver? = type == :class_feature && payload["applies_to"] == "weapon_attack"
  end
end
