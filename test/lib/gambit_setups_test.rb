require "test_helper"
require "rake"

# Pass 6 of the gambits: the task that gives Brenna Ironhide and Corwin Vale (dev-only characters) their
# rules. The two are rebuilt here with the dev characters' class, level, archetype, style and maneuvers (not their
# ability scores or weapon), on the real content of db/seeds; a dry run on dev itself is in the decisions doc.
class GambitSetupsTest < ActiveSupport::TestCase
  BRENNA = [
    [ "Self: HP < 50% → Second Wind", true ],
    [ "Self: HP < 50% → Action Surge", true ],
    [ "Inimigo: menor HP → Ataque", true ],
    [ "Self: qualquer → Action Surge", false ]
  ].freeze
  CORWIN = [
    [ "Self: qualquer → Action Surge", true ],
    [ "Inimigo: recurso ≥ 2 → Maneuver: Precision Attack", true ],
    [ "Self: HP < 25% → Second Wind", true ],
    [ "Inimigo: menor HP → Maneuver: Disarming Attack", true ],
    [ "Inimigo: não marcado → Maneuver: Distracting Strike", false ],
    [ "Inimigo: menor HP → Ataque", true ]
  ].freeze
  # Seeds where every enabled rule of both fires at least once; Corwin's "HP < 25% → Second Wind" needs
  # seed 4 (in 1..40 it fires only in 4, 22, 28 and 32).
  SIMULATION_SEEDS = (1..20).freeze

  setup do
    SeedData.load_all
    # Created before the real ones, so a loose name lookup would find them first.
    @look_alikes = [ "brenna ironhide", "Brenna Ironhide II", "corwin vale" ].map do |name|
      fighter(name, archetype: "martial-archetype-champion", style: "fighting-style-dueling")
        .tap { |character| character.gambits.create!(position: 1, target: :enemy, condition: :highest_hp, action_kind: :attack) }
    end
    @brenna = fighter("Brenna Ironhide", archetype: "martial-archetype-champion", style: "fighting-style-great-weapon-fighting")
    @corwin = fighter("Corwin Vale", archetype: "martial-archetype-battle-master", style: "fighting-style-dueling")
    %w[disarming-attack distracting-strike precision-attack].each do |maneuver|
      @corwin.player_character_maneuvers.create!(maneuver: feature("battle-master-maneuver-#{maneuver}"))
    end
    @bystander = PlayerCharacter.find_by!(name: "Campeão")
    @bystander_rule = @bystander.gambits.create!(position: 1, target: :self, condition: :any, action_kind: :class_feature,
                                                 class_feature: feature("action-surge"))
    # A preset named like Brenna sharing Corwin's id: only the owner type tells their gambits apart.
    @preset = GambitPreset.create!(id: @corwin.id, name: "Brenna Ironhide")
    @preset.gambits.create!(position: 1, target: :enemy, condition: :marked, action_kind: :attack)
  end

  test "apply! gives each one its rules, replacing instead of appending, and leaves everything else alone" do
    @corwin.gambits.create!(position: 1, target: :enemy, condition: :highest_hp, action_kind: :attack) # replaced, not kept
    untouched = -> { [ @brenna, @corwin ].map { |character| [ character.reload.attributes, character.combatant.reload.attributes ] } }
    others = -> { (@look_alikes + [ @bystander, @preset ]).map { |owner| [ owner.reload.attributes, owner.gambits.reload.map(&:attributes) ] } }
    before, before_others = untouched.(), others.()

    GambitSetups.apply!
    count = Gambit.count
    GambitSetups.apply!

    assert_equal count, Gambit.count
    assert_equal BRENNA, rules(@brenna)
    assert_equal CORWIN, rules(@corwin)
    assert_equal before, untouched.(), "the characters themselves changed"
    assert_equal before_others, others.(), "look-alikes, another character or a preset changed"
  end

  test "only the exact name counts: a look-alike never stands in for a missing character" do
    @brenna.destroy!

    error = assert_raises(ActiveRecord::RecordNotFound) { GambitSetups.apply! }

    assert_match "Brenna Ironhide", error.message
    assert_equal [ [ "Inimigo: maior HP → Ataque", true ] ] * 3, @look_alikes.map { |character| rules(character) }.flatten(1)
  end

  test "a missing character aborts the whole run, undoing the characters already applied" do
    @brenna.gambits.create!(position: 1, target: :enemy, condition: :any, action_kind: :attack)
    setups = { "Brenna Ironhide" => GambitSetups::BRENNA_CORWIN.fetch("Brenna Ironhide"), "Ninguém" => [] }

    error = assert_raises(ActiveRecord::RecordNotFound) { GambitSetups.apply!(setups) }

    assert_match "Ninguém", error.message
    assert_equal [ [ "Inimigo: qualquer → Ataque", true ] ], rules(@brenna)
  end

  test "a missing feature aborts with its slug" do
    setups = { "Corwin Vale" => [ { target: :enemy, condition: :any, value: nil, action: "no-such-feature", enabled: true } ] }

    error = assert_raises(ActiveRecord::RecordNotFound) { GambitSetups.apply!(setups) }

    assert_match "no-such-feature", error.message
    assert_empty @corwin.gambits.reload
  end

  test "every enabled rule of both fires in Brenna x Corwin simulations" do
    GambitSetups.apply!
    fired = Hash.new(0)

    SIMULATION_SEEDS.each do |seed|
      brenna, corwin = PlayerCharacter.find(@brenna.id, @corwin.id)
      CombatSimulatorService.new(party_one: [ brenna ], party_two: [ corwin ], seed:).call[:round_log].flat_map { |round| round[:turns] }
        .each { |turn| fired[[ turn[:actor_id], turn.dig(:gambit, :position) ]] += 1 if turn[:gambit].is_a?(Hash) }
    end

    [ @brenna, @corwin ].each do |character|
      character.gambits.reload.select(&:enabled).each do |gambit|
        assert fired[[ character.id, gambit.position ]].positive?, "#{character.name} #{gambit.position}. #{gambit.label} never fired"
      end
    end
  end

  test "the rake task applies the setup, prints it, and is idempotent" do
    output, error, aborted = run_task
    refute aborted, error
    count = Gambit.count
    _, error, aborted = run_task
    refute aborted, error

    assert_equal count, Gambit.count
    assert_equal BRENNA, rules(@brenna)
    assert_equal CORWIN, rules(@corwin)
    assert_includes output, "Brenna Ironhide (id #{@brenna.id})"
    assert_includes output, "Corwin Vale (id #{@corwin.id})"
    assert_includes output, "4. Self: qualquer → Action Surge (desligada)"
  end

  test "the rake task aborts with a clear message, changing nothing, when a character is missing" do
    @corwin.destroy!

    _, error, aborted = run_task

    assert aborted
    assert_includes error, "nada foi alterado: Personagem não encontrado: Corwin Vale"
    assert_empty @brenna.gambits.reload
  end

  private
    # [stdout, stderr, aborted?]: an abort (SystemExit) would otherwise end the test process.
    def run_task
      Rails.application.load_tasks unless Rake::Task.task_defined?("gambits:brenna_corwin")
      task = Rake::Task["gambits:brenna_corwin"].tap(&:reenable)
      aborted = false
      output, error = capture_io do
        task.invoke
      rescue SystemExit
        aborted = true
      end
      [ output, error, aborted ]
    end

    def fighter(name, archetype:, style:)
      PlayerCharacter.create!(name:, level: 4, player_class: PlayerClass.find_by!(name: "Guerreiro"),
                              martial_archetype: feature(archetype), fighting_style: feature(style))
    end

    def feature(slug)
      PlayerClass.find_by!(name: "Guerreiro").class_features.find_by!(slug:)
    end

    def rules(character)
      character.gambits.reload.reorder(:position).map { |gambit| [ gambit.label, gambit.enabled ] }
    end
end
