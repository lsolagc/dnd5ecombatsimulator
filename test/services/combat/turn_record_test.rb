require "test_helper"

class Combat::TurnRecordTest < ActiveSupport::TestCase
  setup do
    @actor = player_characters(:aragorn)
    @record = Combat::TurnRecord.for(actor: @actor, party: :party_one, round: 2, turn: 3, action: { type: :attack }, results: [ { kind: :attack } ])
  end

  test "for builds the header from the actor" do
    assert_equal [ 2, 3, @actor.id, @actor.name, :party_one ], [ @record.round, @record.turn, @record.actor_id, @record.actor_name, @record.actor_party ]
    assert_equal [], Combat::TurnRecord.for(actor: @actor, party: :party_two, round: 1, turn: 1, action: { type: :idle }).results
  end

  test "is immutable and equal by value; with adds the flags without touching the original" do
    assert @record.frozen?
    assert_equal @record, Combat::TurnRecord.for(actor: @actor, party: :party_one, round: 2, turn: 3, action: { type: :attack }, results: [ { kind: :attack } ])

    bonus = @record.with(bonus: true, gambit: "aleatório")

    assert_equal [ true, "aleatório" ], [ bonus.bonus, bonus.gambit ]
    assert_equal [ false, nil ], [ @record.bonus, @record.gambit ]
  end

  test "to_h always uses one key order, omitting gambit, extra and bonus when absent" do
    header = %i[round turn actor_id actor_name actor_party action results]

    assert_equal header, @record.to_h.keys
    assert_equal header + %i[gambit], @record.with(extra: false, gambit: "aleatório").to_h.keys
    # Set in the reverse order: the logged order does not follow the order of the calls.
    assert_equal header + %i[gambit extra bonus], @record.with(bonus: true).with(extra: true).with(gambit: { position: 1 }).to_h.keys
    assert_equal({ round: 2, turn: 3, actor_id: @actor.id, actor_name: @actor.name, actor_party: :party_one, action: { type: :attack },
                   results: [ { kind: :attack } ], gambit: "aleatório", extra: true }, @record.with(extra: true, gambit: "aleatório").to_h)
  end
end
