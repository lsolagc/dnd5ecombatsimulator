module Combat
  # FFXII-style choice of a gambit-driven actor's action (glossary: Gambit policy), one per simulation. Never
  # draws from any RNG: the first enabled rule (top to bottom) whose action is offered right now and whose
  # condition finds a target wins.
  #
  # Works on Gambit objects (saved or not), never querying mid-turn, so a copy of the rules can stand in for
  # the owner's own: given gambits: (a batch's gambit_settings, { combatant id (string) => [Gambit#snapshot,
  # ...] }), each actor's rules are rebuilt from it as unsaved gambits and logged with the copy's own label.
  class GambitPolicy
    def initialize(encounter:, gambits: nil)
      @encounter = encounter
      @settings = gambits
      @labels = {}.compare_by_identity
      @rules = {}
    end

    # The actor's enabled rules by priority (position 1 first), loaded once.
    def rules_for(actor)
      @rules[actor.id] ||= if @settings
        @settings.fetch(actor.id.to_s, []).sort_by { |rule| rule["position"] }.select { |rule| rule["enabled"] }.map do |rule|
          Gambit.new(rule.slice(*Gambit::SNAPSHOT_ATTRIBUTES)).tap { |gambit| @labels[gambit] = rule["label"] }
        end
      else
        actor.gambits.select(&:enabled?).sort_by(&:position)
      end
    end

    # The winning rule's option (one of options, or Action Surge), with the rule's target and gambit set
    # (ActionOption#with), or nil when no rule fires. surging: inside an Action Surge, whose rules are skipped.
    def choose(actor:, options:, surging: false)
      surge = actor.action_surge_option unless surging
      options += [ surge ] if surge

      rules_for(actor).each do |gambit|
        option = options.find { |candidate| action_of?(gambit, candidate) }
        next unless option
        next if gambit.condition_resource_at_least? && !resource_at_least?(actor, option, gambit.condition_value)

        target = target(actor:, gambit:)
        return option.with(target:, gambit:) if target
      end

      nil
    end

    # The rule's target: candidates are the living participants on the rule's side, in initiative order, and
    # the condition picks one (ties go to whoever comes first in initiative). Nil when nobody qualifies.
    def target(actor:, gambit:)
      pool = case gambit.target
      when "self" then [ actor ]
      when "ally" then @encounter.allies_of(actor)
      when "enemy" then @encounter.enemies_of(actor)
      end
      candidates = @encounter.initiative_order.select { |participant| pool.include?(participant) && !participant.dead? }

      case gambit.condition
      when "any", "resource_at_least" then candidates.first # the resource is checked in #choose
      when "hp_below" then candidates.find { |participant| participant.current_hit_points * 100 < gambit.condition_value * participant.max_hit_points }
      when "hp_above" then candidates.find { |participant| participant.current_hit_points * 100 > gambit.condition_value * participant.max_hit_points }
      when "lowest_hp" then candidates.min_by(&:current_hit_points)
      when "highest_hp" then candidates.max_by(&:current_hit_points)
      when "marked" then candidates.find { |participant| participant.status?("next_attack_advantage", not_from: actor) }
      when "unmarked" then candidates.find { |participant| !participant.status?("next_attack_advantage", not_from: actor) }
      else raise ArgumentError, "Unsupported gambit condition: #{gambit.condition.inspect}"
      end
    end

    # The decision entry's gambit: { position:, rule: }, with the copy's label when it came from one.
    def log(gambit)
      { position: gambit.position, rule: @labels[gambit] || gambit.label }
    end

    private

      def action_of?(gambit, option)
        case gambit.action_kind
        when "attack" then option.type == :attack
        when "class_feature" then option.class_feature&.id == gambit.class_feature_id
        when "spell" then option.spell? && option.spell.id == gambit.spell_id
        end
      end

      # The actor's remaining resource for the rule's own action: spell slots of the spell's level, else the
      # feature's uses (the superiority-dice pool for maneuvers). Unlimited uses always pass.
      def resource_at_least?(actor, option, minimum)
        remaining = option.spell? ? actor.available_spell_slots[option.spell.level].to_i : option.uses_remaining
        !remaining.is_a?(Integer) || remaining >= minimum
      end
  end
end
