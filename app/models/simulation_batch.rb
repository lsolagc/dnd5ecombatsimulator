class SimulationBatch < ApplicationRecord
  MAX_SIMULATIONS = 1000
  MAX_SEED = 2**63 - 1
  DAMAGE_TYPES = ConditionAndDamageTypeFormatValidator::EXPECTED_STRUCTURE["damage_types"]
  # One defense per damage type, in the wizard's precedence (an immunity outranks a resistance).
  DEFENSE_COLUMNS = { "I" => "immunities", "R" => "resistances", "V" => "vulnerabilities" }.freeze
  DICE_FORMAT = /\A[1-9]\d*d[1-9]\d*\z/
  # Parallel workers can finish many simulations a second: push progress at most this often.
  PROGRESS_BROADCAST_INTERVAL = 0.2.seconds

  has_many :simulation_runs, -> { order(:id) }

  enum :status, %w[ pending running completed cancelled failed ].index_by(&:itself), default: "pending"

  # A fixed seed always means exactly one (reproducible) simulation.
  before_validation { self.requested_count = 1 if seed.present? }
  before_validation :snapshot_blueprint_settings

  validates :requested_count, numericality: { only_integer: true, in: 1..MAX_SIMULATIONS }
  validates :seed, numericality: { only_integer: true, in: 0..MAX_SEED }, allow_nil: true
  validate :both_sides_have_distinct_existing_combatants

  # The combat parameters a saved character sheet (the blueprint) brings into an experiment.
  def self.blueprint_settings(character)
    combatant = character.combatant
    defenses = DAMAGE_TYPES.filter_map do |type|
      flag, _column = DEFENSE_COLUMNS.find { |_flag, column| combatant.public_send(column).dig("damage_types", type) }
      [ type, flag ] if flag
    end

    {
      "current_hit_points" => character.max_hit_points,
      "armor_class" => combatant.armor_class,
      "attack_bonus" => combatant.attack_bonus,
      "damage_dice" => combatant.damage_dice,
      "damage_type" => combatant.damage_type,
      "defenses" => defenses.to_h
    }
  end

  # Form input, keyed by character id:
  # { "7" => { "side" => "party_one", "current_hit_points" => "12", "armor_class" => "16", "attack_bonus" => "5",
  #            "damage_dice" => "1d8", "damage_type" => "slashing", "defenses" => { "fire" => "R", "cold" => "" } } }
  def combatants=(entries)
    entries = entries.to_h.deep_stringify_keys
    self.party_one_ids = entries.select { |_id, entry| entry["side"] == "party_one" }.keys.map(&:to_i)
    self.party_two_ids = entries.select { |_id, entry| entry["side"] == "party_two" }.keys.map(&:to_i)
    self.combatant_settings = entries.transform_values do |entry|
      {
        "current_hit_points" => to_integer(entry["current_hit_points"]),
        "armor_class" => to_integer(entry["armor_class"]),
        "attack_bonus" => to_integer(entry["attack_bonus"]),
        "damage_dice" => entry["damage_dice"].to_s.strip.downcase,
        "damage_type" => entry["damage_type"].to_s,
        "defenses" => (entry["defenses"] || {}).to_h.compact_blank
      }
    end
  end

  # A new, unsaved experiment with the same combatants and parameters, ready to be tweaked and run again.
  def rerun
    SimulationBatch.new(slice(:party_one_ids, :party_two_ids, :combatant_settings, :requested_count, :seed))
  end

  def settings_for(character)
    combatant_settings[character.id.to_s] || self.class.blueprint_settings(character)
  end

  def finished?
    completed? || cancelled? || failed?
  end

  # Fresh instances on every call, since the simulator mutates HP and spell slots in memory,
  # with the experiment's parameters applied on top of the blueprint. Nothing is saved.
  def party_one
    build_party(party_one_ids)
  end

  def party_two
    build_party(party_two_ids)
  end

  def cancel!
    update!(status: "cancelled") unless finished?
  end

  # The status changes below are single conditional UPDATEs: several worker processes run one batch at once.
  def start!
    SimulationBatch.where(id:, status: "pending").update_all(status: "running", started_at: Time.current)
  end

  # True for the one worker whose simulation was the last one in.
  def complete_if_done!
    SimulationBatch.where(id:, status: "running")
      .where("(SELECT COUNT(*) FROM simulation_runs WHERE simulation_runs.simulation_batch_id = simulation_batches.id) >= requested_count")
      .update_all(status: "completed", updated_at: Time.current) == 1
  end

  def fail!(message)
    SimulationBatch.where(id:, status: %w[ pending running ]).update_all(status: "failed", error_message: message, updated_at: Time.current)
  end

  # Morphs the experiment page's status frame (progress or result) for everyone watching it. Throttled
  # across workers unless forced (the final state must always get through).
  def broadcast_progress(force: false)
    return unless force || claim_progress_broadcast

    reload
    broadcast_update_to self, target: "batch_status", partial: "simulation_batches/status", locals: { batch: self }, attributes: { method: :morph }
  end

  # Simulations finished per second of wall-clock time since the first one started.
  def simulations_per_second
    return if started_at.nil?

    elapsed = Time.current - started_at
    simulation_runs.count / elapsed if elapsed.positive?
  end

  # Bypasses the query cache jobs run under: the cancel comes from the web process, whose UPDATE
  # doesn't clear a worker's cache, so a cached answer would never see it.
  def cancelled_in_database?
    SimulationBatch.uncached { SimulationBatch.where(id:, status: "cancelled").exists? }
  end

  def average_elapsed_ms
    simulation_runs.average(:elapsed_ms)
  end

  def summary
    runs = simulation_runs.unscope(:order)
    {
      total: runs.count,
      wins: runs.group(:winning_party).count,
      healing_done: runs.sum(:healing_done),
      healing_wasted: runs.sum(:healing_wasted),
      max_round_damage: runs.maximum(:max_round_damage).to_i
    }
  end

  # One JSON file per simulation (each carrying its seed) plus a batch.json with the setup and summary.
  def logs_zip
    Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("batch.json")
      zip.write(JSON.pretty_generate(
        id:, status:, requested_count:, seed:,
        party_one: PlayerCharacter.where(id: party_one_ids).pluck(:id, :name).to_h,
        party_two: PlayerCharacter.where(id: party_two_ids).pluck(:id, :name).to_h,
        combatant_settings:,
        summary:
      ))

      simulation_runs.find_each.with_index(1) do |run, index|
        zip.put_next_entry(format("simulation-%04d.json", index))
        zip.write(JSON.pretty_generate({ "simulation" => index, "seed" => run.seed, "elapsed_ms" => run.elapsed_ms }.merge(run.result)))
      end
    end.string
  end

  private

    def claim_progress_broadcast
      SimulationBatch.where(id:)
        .where("progress_broadcast_at IS NULL OR progress_broadcast_at < ?", PROGRESS_BROADCAST_INTERVAL.ago)
        .update_all(progress_broadcast_at: Time.current) == 1
    end

    def to_integer(value)
      Integer(value.to_s.strip, 10, exception: false)
    end

    def build_party(ids)
      PlayerCharacter.includes(:combatant).where(id: ids).map { |character| apply_settings(character) }
    end

    def apply_settings(character)
      settings = settings_for(character)
      defenses = settings["defenses"] || {}
      combatant = character.combatant

      combatant.assign_attributes(
        armor_class: settings["armor_class"],
        attack_bonus: settings["attack_bonus"],
        damage_dice: settings["damage_dice"],
        damage_type: settings["damage_type"],
        **DEFENSE_COLUMNS.to_h do |flag, column|
          [ column, combatant.public_send(column).deep_merge("damage_types" => DAMAGE_TYPES.index_with { |type| defenses[type] == flag }) ]
        end
      )
      character.current_hit_points = settings["current_hit_points"]
      character
    end

    def blueprints
      @blueprints ||= PlayerCharacter.includes(:combatant).where(id: party_one_ids + party_two_ids).index_by(&:id)
    end

    # Keeps exactly one settings entry per selected character, filling the missing ones from the
    # blueprint, so every batch records the parameters it actually ran with.
    def snapshot_blueprint_settings
      self.party_one_ids = party_one_ids.compact.uniq
      self.party_two_ids = party_two_ids.compact.uniq
      @blueprints = nil
      self.combatant_settings = blueprints.to_h do |id, character|
        [ id.to_s, combatant_settings[id.to_s] || self.class.blueprint_settings(character) ]
      end
    end

    def both_sides_have_distinct_existing_combatants
      if party_one_ids.empty? || party_two_ids.empty?
        errors.add(:base, "Cada lado do combate precisa de pelo menos um personagem")
      elsif party_one_ids.intersect?(party_two_ids)
        errors.add(:base, "Um personagem não pode estar nos dois lados")
      elsif blueprints.size != (party_one_ids + party_two_ids).size
        errors.add(:base, "Personagem inexistente selecionado")
      else
        blueprints.each_value { |character| validate_settings(character) }
      end
    end

    def validate_settings(character)
      settings = combatant_settings[character.id.to_s]
      hit_points, armor_class = settings.values_at("current_hit_points", "armor_class")

      problems = []
      problems << "HP inicial deve estar entre 1 e #{character.max_hit_points}" unless hit_points.is_a?(Integer) && hit_points.between?(1, character.max_hit_points)
      problems << "CA deve ser um número inteiro a partir de 0" unless armor_class.is_a?(Integer) && armor_class >= 0
      problems << "bônus de ataque deve ser um número inteiro" unless settings["attack_bonus"].is_a?(Integer)
      problems << "dano deve ter o formato 1d8" unless DICE_FORMAT.match?(settings["damage_dice"].to_s)
      problems << "tipo de dano inválido" unless DAMAGE_TYPES.include?(settings["damage_type"])
      problems << "defesas inválidas" unless (settings["defenses"] || {}).all? { |type, flag| DAMAGE_TYPES.include?(type) && DEFENSE_COLUMNS.key?(flag) }
      problems.each { |problem| errors.add(:base, "#{character.name}: #{problem}") }
    end
end
