module Dice
  # rolls: the value of each die rolled (natural is their sum); just [natural] when built from one value.
  class RollResult
    attr_reader :natural, :total, :rolls

    def initialize(natural:, total:, rolls: [ natural ])
      raise ArgumentError, "natural must be an Integer" unless natural.is_a?(Integer)
      raise ArgumentError, "total must be an Integer" unless total.is_a?(Integer)
      @natural = natural
      @total = total
      @rolls = rolls
    end
  end
end
