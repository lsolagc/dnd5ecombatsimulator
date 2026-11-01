class SimulationBatch < ApplicationRecord
  MAX_SIMULATIONS = 1000
  MAX_SEED = 2**63 - 1
  DICE_FORMAT = /\A[1-9]\d*d[1-9]\d*\z/
  # Parallel workers can finish many simulations a second: push progress at most this often.
  PROGRESS_BROADCAST_INTERVAL = 0.2.seconds

  has_many :simulation_runs, -> { order(:id) }

  enum :status, %w[ pending running completed cancelled failed ].index_by(&:itself), default: "pending"

  # A fixed seed always means exactly one (reproducible) simulation.
  before_validation { self.requested_count = 1 if seed.present? }
  before_validation :snapshot_blueprint_settings
  before_validation :snapshot_gambit_settings

  validates :requested_count, numericality: { only_integer: true, in: 1..MAX_SIMULATIONS }
  validates :seed, numericality: { only_integer: true, in: 0..MAX_SEED }, allow_nil: true
  validate :both_sides_have_distinct_existing_combatants

  # The combat parameters a saved character sheet (the blueprint) brings into an experiment.
  def self.blueprint_settings(character)
    combatant = character.combatant
    {
      "current_hit_points" => character.max_hit_points,
      "armor_class" => combatant.armor_class,
      "attack_bonus" => combatant.attack_bonus,
      "damage_dice" => combatant.damage_dice,
      "damage_type" => combatant.damage_type,
      "defenses" => combatant.defenses.to_h
    }
  end

  # Reads the form's { combatant id => { "side" => ..., settings } } into the sides and combatant_settings: .okf/architecture/simulation-batches.md
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
  # The names are left out: the new batch freezes each character's name as it is then.
  def rerun
    SimulationBatch.new(slice(:party_one_ids, :party_two_ids, :requested_count, :seed)
      .merge(combatant_settings: combatant_settings.transform_values { |settings| settings.except("name") }))
  end

  def settings_for(character)
    combatant_settings[character.combatant.id.to_s] || self.class.blueprint_settings(character)
  end

  def finished?
    completed? || cancelled? || failed?
  end

  # Fresh, read-only instances on every call, with the experiment's parameters applied in memory on top of
  # the blueprint: the simulator only reads them (a save raises ActiveRecord::ReadOnlyRecord).
  def party_one
    build_party(party_one_ids)
  end

  def party_two
    build_party(party_two_ids)
  end

  # The experiment's starting HP, { combatant id => HP }, for Combat::Simulator's hit_points:.
  def hit_points
    (party_one_ids + party_two_ids).index_with { |id| combatant_settings.dig(id.to_s, "current_hit_points") }
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

  # The download (simulacoes-batch-<id>.json): see SimulationBatch::LogExport.
  def logs_json
    LogExport.new(self).json
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
      characters(ids).map { |character| apply_settings(character) }
    end

    # The sheets whose Combatants have these ids; only a PlayerCharacter's Combatant fights in a batch.
    def characters(combatant_ids)
      PlayerCharacter.includes(:combatant).where(id: Combatant.player_characters.where(id: combatant_ids).select(:combatable_id))
    end

    def apply_settings(character)
      settings = settings_for(character)
      combatant = character.combatant

      combatant.assign_attributes(
        armor_class: settings["armor_class"],
        attack_bonus: settings["attack_bonus"],
        damage_dice: settings["damage_dice"],
        damage_type: settings["damage_type"],
        defenses: settings["defenses"] || {}
      )
      combatant.readonly!
      character.tap(&:readonly!)
    end

    def blueprints
      @blueprints ||= characters(party_one_ids + party_two_ids).index_by { |character| character.combatant.id }
    end

    # One settings entry per selected character, missing ones from the blueprint, the name frozen once: .okf/architecture/simulation-batches.md
    def snapshot_blueprint_settings
      self.party_one_ids = party_one_ids.compact.uniq
      self.party_two_ids = party_two_ids.compact.uniq
      @blueprints = nil
      self.combatant_settings = blueprints.to_h do |id, character|
        settings = combatant_settings[id.to_s] || self.class.blueprint_settings(character)
        settings = settings.reverse_merge("name" => character.name) if new_record?
        [ id.to_s, settings ]
      end
    end

    # Copies each character's gambits (every rule, in priority order) once, when the batch is created:
    # every run simulates from this copy, so editing the rules later changes neither the runs nor the log.
    def snapshot_gambit_settings
      self.gambit_settings = blueprints.to_h do |id, character|
        [ id.to_s, gambit_settings[id.to_s] || character.gambits.sort_by(&:position).map(&:snapshot) ]
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
      settings = combatant_settings[character.combatant.id.to_s]
      hit_points, armor_class = settings.values_at("current_hit_points", "armor_class")

      problems = []
      problems << "HP inicial deve estar entre 1 e #{character.max_hit_points}" unless hit_points.is_a?(Integer) && hit_points.between?(1, character.max_hit_points)
      problems << "CA deve ser um número inteiro a partir de 0" unless armor_class.is_a?(Integer) && armor_class >= 0
      problems << "bônus de ataque deve ser um número inteiro" unless settings["attack_bonus"].is_a?(Integer)
      problems << "dano deve ter o formato 1d8" unless DICE_FORMAT.match?(settings["damage_dice"].to_s)
      problems << "tipo de dano inválido" unless Combatant::Defenses::TYPES.include?(settings["damage_type"])
      problems << "defesas inválidas" unless valid_defenses?(settings["defenses"] || {})
      problems.each { |problem| errors.add(:base, "#{character.name}: #{problem}") }
    end

    def valid_defenses?(defenses)
      return false unless defenses.is_a?(Hash)

      Combatant::Defenses.new(defenses)
      true
    rescue ArgumentError
      false
    end
end
