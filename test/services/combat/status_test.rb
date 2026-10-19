require "test_helper"

class Combat::StatusTest < ActiveSupport::TestCase
  test "kinds and ends come from one closed vocabulary" do
    source = Combat::Participant.new(player_characters(:aragorn))

    assert_equal %w[next_attack_advantage disadvantage_on_next_save], Combat::Status::KINDS
    assert_equal %w[source_turn_start], Combat::Status::ENDS
    status = Combat::Status.new(kind: "next_attack_advantage", source:, ends: "source_turn_start")
    assert_equal [ "next_attack_advantage", source, "source_turn_start" ], [ status.kind, status.source, status.ends ]
    assert_nil Combat::Status.new(kind: "disadvantage_on_next_save", source:).ends, "no end of its own: only consumed"
    assert_raises(ArgumentError) { Combat::Status.new(kind: "stunned", source:) }
    assert_raises(ArgumentError) { Combat::Status.new(kind: "next_attack_advantage", source:, ends: "end_of_round") }
  end
end
