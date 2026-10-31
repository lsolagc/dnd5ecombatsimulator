require "test_helper"

class Combat::GambitPolicyTest < ActiveSupport::TestCase
  test "an ally rule includes the actor itself" do
    actor = player_characters(:elora)
    mend = Spell.create!(name: "Test Mend", slug: "test-mend", level: 0, school: "evocation", description: "Test-only ally heal.",
                         effect_payload: { kind: "heal", roll: "1d4", target: "ally" })
    PlayerCharacterSpell.create!(player_character: actor, spell: mend)
    ally = player_characters(:aragorn)
    enemy = player_characters(:merlin)
    actor.gambits.build(position: 1, target: :ally, condition: :hp_below, condition_value: 50, action_kind: :spell, spell: mend)
    # Below 50% of 10; the ally sturdy, so only the actor qualifies.
    encounter = build_encounter(party_one: [ ally, actor ], party_two: [ enemy ], hit_points: { actor.combatant.id => 4, ally.combatant.id => 1000 })
    actor = participant_of(encounter, actor)

    chosen = Combat::GambitPolicy.new(encounter:).choose(actor:, options: actor.action_options)

    assert_equal :cast_spell, chosen&.type
    assert_equal actor, chosen.target
  end

  test "hp_below fires only strictly below the threshold" do
    actor = player_characters(:thorin)
    enemy = player_characters(:aragorn) # max 12
    gambit = actor.gambits.build(position: 1, target: :enemy, condition: :hp_below, condition_value: 50, action_kind: :attack)
    encounter = build_encounter(party_one: [ actor ], party_two: [ enemy ], hit_points: { enemy.combatant.id => 6 }) # exactly 50%
    actor, enemy = participant_of(encounter, actor), participant_of(encounter, enemy)
    policy = Combat::GambitPolicy.new(encounter:)

    assert_nil policy.target(actor:, gambit:)

    enemy.take_damage(amount: 1, damage_type: "force")
    assert_equal enemy, policy.target(actor:, gambit:)

    # 62/125 = 49.6%: below 50% even though it rounds to 50.
    enemy.character.max_hit_points = 125
    enemy.heal(57)
    assert_equal enemy, policy.target(actor:, gambit:)
  end

  test "a copy of the rules stands in for the actor's own: enabled ones by position, logged with the copy's label" do
    actor = player_characters(:aragorn)
    actor.gambits.build(position: 1, target: :enemy, condition: :any, action_kind: :attack) # its own rule
    second_wind = Gambit.new(position: 2, target: :self, condition: :any, action_kind: :class_feature, class_feature: class_features(:fighter_second_wind))
    attack = Gambit.new(position: 1, target: :enemy, condition: :any, action_kind: :attack)
    disabled = Gambit.new(position: 3, target: :enemy, condition: :any, action_kind: :attack, enabled: false)
    copy = { actor.combatant.id.to_s => [ second_wind.snapshot.merge("label" => "rótulo da cópia"), disabled.snapshot, attack.snapshot ] }
    encounter = build_encounter(party_one: [ actor ], party_two: [ player_characters(:merlin) ])
    policy = Combat::GambitPolicy.new(encounter:, gambits: copy)

    rules = policy.rules_for(participant_of(encounter, actor))

    assert_equal [ 1, 2 ], rules.map(&:position)
    assert rules.none?(&:persisted?)
    assert_equal [ { position: 1, rule: attack.label }, { position: 2, rule: "rótulo da cópia" } ], rules.map { |rule| policy.log(rule) }
  end
end
