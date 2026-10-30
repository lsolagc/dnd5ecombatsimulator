require "test_helper"

class GambitsHelperTest < ActionView::TestCase
  setup do
    @aragorn = player_characters(:aragorn)
    @second_wind = class_features(:fighter_second_wind)
  end

  test "the options are the character's gambit actions as [label, value] pairs" do
    expected = [ [ "Ataque", "attack" ], [ "Second Wind", "class_feature:#{@second_wind.id}" ] ]

    assert_equal expected, gambit_action_options(@aragorn, Gambit.new(action_kind: :class_feature, class_feature: @second_wind))
    assert_equal expected, gambit_action_options(@aragorn, Gambit.new), "a new gambit without an action adds nothing"
  end

  test "a stored action the character lacks stays listed, marked unavailable" do
    fire_bolt = spells(:fire_bolt)

    assert_equal [ "Fire Bolt (indisponível)", "spell:#{fire_bolt.id}" ],
      gambit_action_options(@aragorn, Gambit.new(action_kind: :spell, spell: fire_bolt)).last
    assert_equal 2, gambit_action_options(@aragorn, Gambit.new(action_kind: :attack)).size, "the unavailable option does not stick"
  end

  test "each character gets its own options within one request" do
    gambit_action_options(@aragorn, Gambit.new)

    assert_equal [ "Ataque", "Second Wind", "Action Surge" ], gambit_action_options(player_characters(:thorin), Gambit.new).map(&:first)
  end

  test "the character's actions are looked up once per request" do
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
    gambit_action_options(@aragorn, Gambit.new)
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      gambit_action_options(@aragorn, Gambit.new(action_kind: :attack))
    end
    assert_equal 0, queries
  end
end
