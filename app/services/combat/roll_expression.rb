module Combat
  # Parses and evaluates a roll expression such as "1d10 + actor_level": .okf/architecture/combat-effect-pipeline.md (Contract)
  class RollExpression
    DICE_PATTERN     = /\A\d+d\d+\z/i
    NUMBER_PATTERN   = /\A\d+\z/
    VARIABLE_PATTERN = /\A[a-z][a-z_]*\z/

    def initialize(expression:)
      @raw = expression.to_s
      @expression = expression.to_s.downcase.gsub(/\s+/, "")
    end

    # crit: a critical hit rolls twice the dice of every dice term (5e), never doubling the flat modifiers.
    # The outcome's dice are the terms as rolled ("2d10" for a critical "1d10"), its rolls one value per die.
    def resolve(context:, crit: false)
      tokens = tokenize

      dice_terms       = []
      dice_rolls       = []
      modifiers        = {}
      total            = 0

      tokens.each do |sign, term|
        multiplier = sign == "-" ? -1 : 1

        if term.match?(DICE_PATTERN)
          result = Dice.roll(dice: term, modifier: 0, crit:)
          dice_terms  << "#{result.rolls.size}d#{term.split("d").last}"
          dice_rolls.concat(result.rolls)
          total       += result.natural * multiplier
        elsif term.match?(NUMBER_PATTERN)
          total += term.to_i * multiplier
        elsif term.match?(VARIABLE_PATTERN)
          value = context.resolve(term).to_i
          modifiers[term] = value * multiplier
          total += value * multiplier
        else
          raise ArgumentError, "Unrecognized term '#{term}' in roll expression '#{@raw}'"
        end
      end

      RollOutcome.new(
        expression:          @raw,
        resolved_expression: build_resolved_expression(tokens, context),
        dice:                dice_terms,
        rolls:               dice_rolls,
        modifiers:           modifiers,
        total:               total
      )
    end

    private

      def tokenize
        expr = @expression.dup
        expr = "+#{expr}" unless expr.start_with?("+", "-")

        expr.scan(/([+-])([a-z0-9_]+)/).map { |sign, term| [ sign, term ] }
      end

      def build_resolved_expression(tokens, context)
        parts = tokens.map do |sign, term|
          sign_str = sign == "+" ? "+" : "-"

          if term.match?(DICE_PATTERN) || term.match?(NUMBER_PATTERN)
            "#{sign_str}#{term}"
          elsif term.match?(VARIABLE_PATTERN)
            "#{sign_str}#{context.resolve(term).to_i.abs}"
          end
        end
        parts.join.sub(/\A\+/, "")
      end
  end
end
