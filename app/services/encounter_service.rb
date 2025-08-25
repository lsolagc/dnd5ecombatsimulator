class EncounterService
  attr_reader :encounter_log

  def initialize(party_one:, party_two:, reset_hit_points: true)
    raise ArgumentError, "Both parties must be Arrays" unless party_one.is_a?(Array) && party_two.is_a?(Array)
    raise ArgumentError, "Parties must not be empty" if party_one.empty? || party_two.empty?

    @party_one = party_one
    @party_two = party_two
    @reset_hit_points = reset_hit_points
    @encounter_log = {}
    @round_number = 0
  end

  def call
    initialize_hit_points if @reset_hit_points

    roll_initiative

    setup_encounter_log

    loop do
      break if encounter_over?

      @round_number += 1
      execute_round
    end

    cleanup

    self
  end

  private

    def initialize_hit_points
      @party_one.each do |combatant|
        combatant.current_hit_points = combatant.max_hit_points
      end
      @party_two.each do |combatant|
        combatant.current_hit_points = combatant.max_hit_points
      end
    end

    def setup_encounter_log
      @encounter_log[:rounds] = {}
      @encounter_log[:rounds][@round_number] = {
        participants: {
          party_one: @party_one.map(&:name),
          party_two: @party_two.map(&:name)
        },
        round_order: @round_order
      }
    end

    def roll_initiative
      initiative_rolls = {}

      @party_one.each do |combatant|
        initiative_rolls[combatant] = Dice.d20(modifier: combatant.initiative).total
      end

      @party_two.each do |combatant|
        initiative_rolls[combatant] = Dice.d20(modifier: combatant.initiative).total
      end

      @round_order = initiative_rolls.sort_by { |_, roll| -roll }.to_h
      @round_order
    end

    def execute_round
      @encounter_log[:rounds][@round_number] = []

      @round_order.each do |combatant, initiative_roll|
        next if combatant.dead?

        target_party = @party_one.include?(combatant) ? @party_two : @party_one
        target = target_party.reject { |m| m.dead? }.sample

        attack_roll, damage_roll = combatant.roll_an_attack
        attack_result = target.get_attacked(attack_roll:, damage_roll:)

        round_result = {
          initiative: initiative_roll,
          combatant: combatant.name,
          combatant_hit_points: combatant.current_hit_points,
          target: target.name,
          attack_roll: attack_result[:attack_roll],
          success: attack_result[:success],
          damage: attack_result[:damage],
          message: attack_result[:message]
        }

        @encounter_log[:rounds][@round_number] << round_result
      end
    end

    def encounter_over?
      @party_one.all?(&:dead?) || @party_two.all?(&:dead?)
    end

    def cleanup
      if @party_one.all?(&:dead?)
        winner = @party_two
      elsif @party_two.all?(&:dead?)
        winner = @party_one
      else
        winner = [ Struct.new(:name) { "No winner" } ]
      end

      @encounter_log[:end_of_encounter] = {
        winner: winner.map(&:name),
        number_of_rounds: @round_number
      }
    end
end
