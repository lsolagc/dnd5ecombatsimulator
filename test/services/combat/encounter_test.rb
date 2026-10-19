require "test_helper"

class Combat::EncounterTest < ActiveSupport::TestCase
  setup do
    @a, @b, @c, @d = [ :aragorn, :aragorn_copy, :merlin, :eldritch_knight_ten ].map { |name| Combat::Participant.new(player_characters(name)) }
    @encounter = Combat::Encounter.new(party_one: [ @a, @b ], party_two: [ @c, @d ])
  end

  test "knows each side: party, allies (the participant included) and enemies" do
    assert_equal [ @a, @b, @c, @d ], @encounter.participants
    assert_equal [ @a, @b, @c, @d ], @encounter.initiative_order, "party order until initiative is rolled"
    assert_equal :party_one, @encounter.party_for(@b)
    assert_equal :party_two, @encounter.party_for(@c)
    assert_equal [ @a, @b ], @encounter.allies_of(@a)
    assert_equal [ @c, @d ], @encounter.enemies_of(@a)
    assert_equal [ @a, @b ], @encounter.enemies_of(@d)
  end

  test "the first living enemy goes by initiative order, and the fight is over once a side is down" do
    @encounter.initiative_order = [ @d, @b, @c, @a ]
    assert_equal @d, @encounter.first_living_enemy(@a)

    @d.take_damage(amount: 1000, damage_type: "force")
    assert_equal @c, @encounter.first_living_enemy(@a)
    assert_equal [ @c ], @encounter.alive(@encounter.party_two)
    assert_not @encounter.over?

    @c.take_damage(amount: 1000, damage_type: "force")
    assert_nil @encounter.first_living_enemy(@a)
    assert @encounter.over?
  end

  test "start_turn expires on every participant the statuses the actor applied that end at the start of its turn" do
    mark = ->(source) { Combat::Status.new(kind: "next_attack_advantage", source:, ends: "source_turn_start") }
    eldritch = Combat::Status.new(kind: "disadvantage_on_next_save", source: @a, ends: nil)
    @c.add_status(mark.(@a))
    @d.add_status(mark.(@a))
    @d.add_status(mark.(@b))
    @d.add_status(eldritch)

    @a.take_damage(amount: 1000, damage_type: "force")
    @encounter.start_turn(@a)

    assert_empty @c.statuses, "a dead source's marks expire too"
    assert_equal [ mark.(@b), eldritch ], @d.statuses
  end
end
