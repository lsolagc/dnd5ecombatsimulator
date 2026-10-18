module Combat
  # One action the actor can take this turn, as CombatSimulatorService lists it: a weapon attack, a class
  # feature (a maneuver rides on an attack), a spell, or Action Surge (a gambit-only option). A gambit's
  # pick is the same option with the rule's target and gambit filled in (#with).
  #
  # type:           :attack | :class_feature | :cast_spell | :action_surge
  # class_feature:  the ClassFeature (:class_feature, :action_surge)
  # spell:          the Spell (:cast_spell)
  # payload:        the feature's action payload at the actor's level, or the spell's effect payload
  # uses_remaining: the uses left of the resource it spends (nil: unlimited)
  # target, gambit: set when a gambit chose it
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
