# Gambit configurations for named characters that live only in the dev database (not in the YAML seeds),
# applied by `bin/rails gambits:brenna_corwin` (.okf/architecture/gambits-decisions.md, Pass 6).
#
# Idempotent: each run replaces the listed characters' gambits and touches no other row. One transaction
# for all of them: a missing character or feature aborts the whole run, changing nothing.
module GambitSetups
  # Rules in priority order. action: :attack or the slug of a feature of the character's class.
  BRENNA_CORWIN = {
    "Brenna Ironhide" => [
      { target: :self, condition: :hp_below, value: 50, action: "second-wind", enabled: true },
      # Action Surge only takes the Self target: "Inimigo: HP < 30%" is rejected by the model (Pass 6).
      { target: :self, condition: :hp_below, value: 50, action: "action-surge", enabled: true },
      { target: :enemy, condition: :lowest_hp, value: nil, action: :attack, enabled: true },
      { target: :self, condition: :any, value: nil, action: "action-surge", enabled: false }
    ],
    "Corwin Vale" => [
      { target: :self, condition: :any, value: nil, action: "action-surge", enabled: true },
      # Precision keeps one die back for Disarming.
      { target: :enemy, condition: :resource_at_least, value: 2, action: "battle-master-maneuver-precision-attack", enabled: true },
      { target: :self, condition: :hp_below, value: 25, action: "second-wind", enabled: true },
      { target: :enemy, condition: :lowest_hp, value: nil, action: "battle-master-maneuver-disarming-attack", enabled: true },
      # The mark only helps other attackers: on in a 1x1 it would swallow the dice. Off, for group fights.
      { target: :enemy, condition: :unmarked, value: nil, action: "battle-master-maneuver-distracting-strike", enabled: false },
      { target: :enemy, condition: :lowest_hp, value: nil, action: :attack, enabled: true }
    ]
  }.freeze

  module_function

  # Returns { character => [gambits] }. Raises ActiveRecord::RecordNotFound (name or slug in the
  # message) or ActiveRecord::RecordInvalid, after rolling everything back.
  def apply!(setups = BRENNA_CORWIN)
    Gambit.transaction do
      setups.to_h do |name, rules|
        character = PlayerCharacter.find_by(name:) or raise ActiveRecord::RecordNotFound, "Personagem não encontrado: #{name}"
        Gambit.where(owner: character).delete_all
        character.gambits.reset
        gambits = rules.each.with_index(1).map do |rule, position|
          character.gambits.create!(position:, target: rule[:target], condition: rule[:condition],
                                    condition_value: rule[:value], enabled: rule[:enabled], **action(character, rule[:action]))
        end
        [ character, gambits ]
      end
    end
  end

  def action(character, action)
    return { action_kind: :attack } if action == :attack

    feature = character.player_class.class_features.find_by(slug: action) or
      raise ActiveRecord::RecordNotFound, "Feature #{action} não encontrada na classe de #{character.name}"
    { action_kind: :class_feature, class_feature: feature }
  end
end
