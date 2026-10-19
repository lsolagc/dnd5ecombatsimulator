module Combat
  # The fight as a whole (glossary: Encounter): the two parties of Combat::Participants and the initiative
  # order, who is on whose side, who is still standing and when it is over. The statuses live on the
  # participants that carry them; the encounter only expires them as turns start.
  class Encounter
    attr_reader :party_one, :party_two, :participants
    # The order turns are taken in; party order until CombatSimulatorService rolls initiative.
    attr_accessor :initiative_order

    def initialize(party_one:, party_two:)
      @party_one = party_one
      @party_two = party_two
      @participants = party_one + party_two
      @initiative_order = @participants
    end

    # :party_one or :party_two.
    def party_for(participant)
      party_one.include?(participant) ? :party_one : :party_two
    end

    # The participant's own party, the participant included.
    def allies_of(participant)
      party_for(participant) == :party_one ? party_one : party_two
    end

    def enemies_of(participant)
      party_for(participant) == :party_one ? party_two : party_one
    end

    def alive(party)
      party.reject(&:dead?)
    end

    # The first living enemy in initiative order, or nil.
    def first_living_enemy(participant)
      enemies = enemies_of(participant)
      initiative_order.find { |candidate| enemies.include?(candidate) && !candidate.dead? }
    end

    def over?
      alive(party_one).empty? || alive(party_two).empty?
    end

    # The actor's turn starts (dead or alive): every status it applied that ends at the start of its turn goes.
    def start_turn(actor)
      participants.each { |participant| participant.expire_statuses!(source: actor) }
    end
  end
end
