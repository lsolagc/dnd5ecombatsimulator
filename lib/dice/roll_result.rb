module Dice
  class RollResult
    attr_reader :natural, :total

    def initialize(natural:, total:)
      raise ArgumentError, "natural must be an Integer" unless natural.is_a?(Integer)
      raise ArgumentError, "total must be an Integer" unless total.is_a?(Integer)
      @natural = natural
      @total = total
    end
  end
end
