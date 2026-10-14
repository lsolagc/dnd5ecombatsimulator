# Safety net for refactoring CombatSimulatorService (.okf/ops/combat-regression.md): the compositions
# that the golden-file test, the query-ceiling test and the benchmark all run, on the content of
# db/seeds. Every helper that writes to the database must run inside a transaction that rolls back.
module CombatRegression
  DIR = Rails.root.join("test/fixtures/files/combat_regression")
  SEEDS = (1..12).to_a

  # Each character is a seed character (distinct per composition), changed only for the composition:
  # level, spells learned on top of the seed's, the maneuvers known (replacing the seed's) and gambits
  # (add_rule's shorthand in test/services/combat_simulator_gambit_coverage_test.rb).
  COMPOSITIONS = {
    # 1v1, random: Champion crits, Second Wind, Action Surge on the random path, maneuvers at random.
    "campeao-vs-mestre" => {
      max_rounds: 20,
      party_one: [ { name: "Campeão" } ],
      party_two: [ { name: "Mestre de Batalha" } ]
    },
    # 2v1, gambits: Distracting Strike marks the Champion, the Eldritch Knight attacks the mark with
    # advantage, War Magic after Fire Bolt; the Champion surges by gambit and stands idle inside it.
    "mestre-cavaleiro-vs-campeao-gambits" => {
      max_rounds: 20,
      party_one: [
        { name: "Mestre de Batalha", maneuvers: %w[distracting-strike precision-attack riposte],
          gambits: [ { feature: "battle-master-maneuver-distracting-strike" }, {} ] },
        { name: "Cavaleiro Arcano", level: 7,
          gambits: [ { condition: :marked }, { spell: "fire-bolt" } ] }
      ],
      party_two: [
        { name: "Campeão", level: 10,
          gambits: [ { target: :self, feature: "action-surge" },
                     { target: :self, condition: :hp_below, condition_value: 50, feature: "second-wind" },
                     { condition: :hp_below, condition_value: 90 } ] }
      ]
    },
    # 1v1, random caster: Eldritch Strike before Fireball (disadvantage on the save), War Magic after cantrips.
    "cavaleiro-vs-campeao" => {
      max_rounds: 20,
      party_one: [ { name: "Cavaleiro Arcano", level: 13, spells: %w[fireball scorching-ray] } ],
      party_two: [ { name: "Campeão", level: 9 } ]
    },
    # 2v1, random, Improved War Magic.
    "campeao-cavaleiro-vs-mestre" => {
      max_rounds: 20,
      party_one: [ { name: "Campeão" }, { name: "Cavaleiro Arcano", level: 18, spells: %w[fireball] } ],
      party_two: [ { name: "Mestre de Batalha", level: 15 } ]
    },
    # 1v1 cut short: reaches :max_rounds_reached.
    "mestre-vs-cavaleiro-curto" => {
      max_rounds: 2,
      party_one: [ { name: "Mestre de Batalha" } ],
      party_two: [ { name: "Cavaleiro Arcano" } ]
    }
  }.freeze

  module_function

  def golden_path(name) = DIR.join("#{name}.yml")
  def query_baseline_path = DIR.join("queries.yml")
  def benchmark_baseline_path = DIR.join("benchmark.yml")

  # Loads db/seeds and pins the physical order of the unlocks, which the simulator reads with no ORDER BY:
  # the turn's candidate actions follow that order, so without this a seed would not always replay.
  def load_seeds!
    SeedData.load_all
    ActiveRecord::Base.connection.execute("CLUSTER class_feature_unlocks USING class_feature_unlocks_pkey")
  end

  # Applies the composition's changes to the seed characters (load_seeds! must have run).
  def prepare!(composition)
    characters(composition).each do |spec|
      character = PlayerCharacter.find_by!(name: spec[:name])
      character.update!(level: spec[:level]) if spec[:level]
      Array(spec[:spells]).each { |slug| character.player_character_spells.find_or_create_by!(spell: Spell.find_by!(slug:)) }
      if spec[:maneuvers]
        character.player_character_maneuvers.destroy_all
        spec[:maneuvers].each { |slug| character.player_character_maneuvers.create!(maneuver: feature(character, "battle-master-maneuver-#{slug}")) }
      end
      Array(spec[:gambits]).each.with_index(1) { |rule, position| add_rule!(character, position:, **rule) }
    end
  end

  # Runs the block with the composition applied, rolling the changes back (compositions change the same
  # characters); returns the block's value.
  def within(composition)
    value = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      prepare!(composition)
      value = yield
      raise ActiveRecord::Rollback
    end
    value
  end

  # One simulation on fresh records (HP, spell slots and caches start over).
  def simulate(composition, seed)
    party_one, party_two = composition.values_at(:party_one, :party_two).map do |party|
      party.map { |spec| with_ordered_spells(PlayerCharacter.find_by!(name: spec[:name])) }
    end
    yield CombatSimulatorService.new(party_one:, party_two:, seed:, max_rounds: composition[:max_rounds])
  end

  # Queries run inside the block, schema lookups aside.
  def count_queries
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| count += 1 unless payload[:name] == "SCHEMA" }
    yield
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  # The highest query count of any seed of the composition.
  def queries_per_sim(composition)
    SEEDS.map { |seed| simulate(composition, seed) { |service| count_queries { service.call } } }.max
  end

  # The result with record ids (which change between runs: sequences are not rolled back) replaced by
  # stable labels: character name, feature or spell slug. Any other id key fails loudly.
  def normalize(value, key = nil)
    case value
    when Hash then value.to_h { |k, v| [ k, normalize(v, k) ] }
    when Array then value.map { |item| normalize(item) }
    else
      case key
      when :id, :actor_id, :target_id then PlayerCharacter.find(value).name
      when :feature_id then ClassFeature.find(value).slug
      when :spell_id then Spell.find(value).slug
      else
        raise ArgumentError, "unexpected id #{key.inspect} in a simulation result" if key.to_s.end_with?("_id")

        value
      end
    end
  end

  # One benchmark sample: mean ms per simulation over every seed (the composition applied).
  def ms_per_sim(composition)
    services = SEEDS.map { |seed| simulate(composition, seed) { it } }
    elapsed_ms { services.each(&:call) } / services.size
  end

  # The benchmark's yardstick: fixed work outside the simulator (trivial queries and plain Ruby), timed
  # in the same rounds. Dividing by it cancels the machine's own drift between runs (±15% seen on WSL).
  REFERENCE_DATA = Array.new(1_000) { |index| { round: index, results: [ { kind: :attack, total: index % 20 } ] } }.freeze
  def reference_ms
    connection = ActiveRecord::Base.connection
    elapsed_ms do
      30.times { connection.select_value("SELECT 1") }
      10.times { Marshal.load(Marshal.dump(REFERENCE_DATA)) }
    end
  end

  def elapsed_ms
    GC.start
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond) - started
  end

  # The spells load with no ORDER BY either (a hash join on a table SeedData updates in place, so their
  # order changes between runs): preloaded here in the order they were learned.
  def with_ordered_spells(character)
    character.association(:spells).target = character.spells.order("player_character_spells.id").to_a
    character
  end

  def characters(composition) = composition.values_at(:party_one, :party_two).flatten

  def feature(character, slug) = character.player_class.class_features.find_by!(slug:)

  def add_rule!(character, position:, target: :enemy, condition: :any, feature: nil, spell: nil, **attributes)
    action = if feature then { action_kind: :class_feature, class_feature: feature(character, feature) }
    elsif spell then { action_kind: :spell, spell: Spell.find_by!(slug: spell) }
    else { action_kind: :attack }
    end
    character.gambits.create!(position:, target:, condition:, **action, **attributes)
  end
end
