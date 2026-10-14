require "test_helper"
require "minitest/mock"

# Safety net for refactoring CombatSimulatorService (.okf/ops/combat-regression.md): every composition of
# CombatRegression, on every seed, must replay its golden file byte for byte and stay under its query
# ceiling. COMBAT_REGRESSION_WRITE=1 (bin/rails combat_regression:regenerate) rewrites both instead.
class CombatRegressionTest < ActiveSupport::TestCase
  WRITE = ENV["COMBAT_REGRESSION_WRITE"] == "1"

  setup { CombatRegression.load_seeds! }

  test "every seeded simulation replays its golden file and the set covers the mechanics it guards" do
    eldritch_saves = 0
    run = Combat::ActionRunner.method(:call)
    spy = ->(**options) { eldritch_saves += 1 if options[:disadvantage_on_save]; run.(**options) }

    results = Combat::ActionRunner.stub(:call, spy) do
      CombatRegression::COMPOSITIONS.flat_map do |name, composition|
        each_composition_seed(name, composition) do |seeded|
          yaml = YAML.dump(seeded)
          path = CombatRegression.golden_path(name)
          WRITE ? File.write(path, yaml) : assert_equal(File.read(path), yaml, "#{name}: the simulation changed")
          seeded.values
        end
      end
    end

    assert_operator results.size, :>=, 60
    assert_empty missing_coverage(results, eldritch_saves:), "the regression set no longer exercises these"
  end

  test "no composition goes over its query ceiling per simulation" do
    counts = CombatRegression::COMPOSITIONS.to_h do |name, composition|
      [ name, CombatRegression.within(composition) { CombatRegression.queries_per_sim(composition) } ]
    end
    return File.write(CombatRegression.query_baseline_path, YAML.dump(counts)) if WRITE

    YAML.load_file(CombatRegression.query_baseline_path).each do |name, baseline|
      assert_operator counts.fetch(name), :<=, baseline * 1.1, "#{name}: queries per simulation went over the baseline + 10%"
    end
  end

  private

    def each_composition_seed(name, composition)
      CombatRegression.within(composition) do
        yield CombatRegression::SEEDS.to_h { |seed| [ seed, CombatRegression.normalize(CombatRegression.simulate(composition, seed, &:call)) ] }
      end
    end

    def missing_coverage(results, eldritch_saves:)
      entries = results.flat_map { |result| result[:round_log].flat_map { |round| round[:turns] } }
      attacks = entries.flat_map { |entry| entry[:results] }.select { |effect| effect[:kind] == :attack }
      type = ->(entry) { entry.dig(:action, :type) }
      # Damage as rolled (an attack's damage, an effect's amount, before defenses) against the HP it took.
      damage = entries.flat_map { |entry| entry[:results].flat_map { |effect| [ effect, effect[:rider] ].compact } }
        .filter_map { |effect| [ effect[:kind] == :attack ? effect[:damage] : effect[:amount], effect[:hp_before] - effect[:hp_after], effect[:hp_after] ] if effect[:kind].in?(%i[attack damage]) }
        .select { |rolled, _taken, hp_after| rolled.to_i.positive? && hp_after.positive? }
      {
        "critical hit" => attacks.any? { |attack| attack[:success] && attack.dig(:attack_roll, :crit) },
        "maneuver rider" => attacks.any? { |attack| attack[:rider] },
        "maneuver rider on a critical hit" => attacks.any? { |attack| attack[:rider] && attack.dig(:attack_roll, :crit) },
        "advantage from Distracting Strike" => attacks.any? { |attack| attack[:advantage] },
        "cast_spell turn" => entries.any? { |entry| type.(entry) == :cast_spell },
        "War Magic bonus attack" => entries.any? { |entry| entry[:bonus] },
        "random Action Surge" => entries.any? { |entry| entry[:extra] && entry[:gambit] == CombatSimulatorService::RANDOM_GAMBIT },
        "Action Surge by gambit" => entries.any? { |entry| type.(entry) == :action_surge },
        "Second Wind heal" => entries.any? { |entry| entry.dig(:action, :feature_slug) == "second-wind" && entry[:results].any? { |effect| effect[:kind] == :heal } },
        "entry driven by a gambit" => entries.any? { |entry| entry[:gambit].is_a?(Hash) && entry[:gambit].keys == %i[position rule] },
        "idle entry" => entries.any? { |entry| type.(entry) == :idle },
        "victory" => results.any? { |result| result[:outcome] == :victory },
        "max_rounds_reached" => results.any? { |result| result[:outcome] == :max_rounds_reached },
        "Eldritch Strike disadvantage on a save" => eldritch_saves.positive?,
        "damage halved by a resistance" => damage.any? { |rolled, taken, _| rolled >= 2 && taken == rolled / 2 },
        "damage blocked by an immunity" => damage.any? { |_, taken, _| taken.zero? },
        "damage doubled by a vulnerability" => damage.any? { |rolled, taken, _| taken == rolled * 2 }
      }.reject { |_, covered| covered }.keys
    end
end
