# A combatant's defenses: { damage type => "I" | "R" | "V" } (immunity, resistance, vulnerability), only the
# defended types. Stored in the Combatant's immunities/resistances/vulnerabilities columns ("damage_types"
# section); a type has one defense at most (Combatant validates it). Immutable.
class Combatant::Defenses
  TYPES = ConditionAndDamageTypeFormatValidator::EXPECTED_STRUCTURE["damage_types"]
  # Flag => the Combatant column it lives in, in reading precedence (an immunity outranks a resistance).
  FLAGS = { "I" => "immunities", "R" => "resistances", "V" => "vulnerabilities" }.freeze

  def self.of(combatant)
    new(TYPES.filter_map do |type|
      flag, _column = FLAGS.find { |_flag, column| combatant.public_send(column).dig("damage_types", type) }
      [ type, flag ] if flag
    end.to_h)
  end

  # flags: { damage type => flag } (a Hash or Defenses); raises ArgumentError on an unknown type or flag.
  def initialize(flags = {})
    @flags = flags.to_h.to_h { |type, flag| [ type.to_s, flag ] }.freeze
    invalid = @flags.reject { |type, flag| TYPES.include?(type) && FLAGS.key?(flag) }
    raise ArgumentError, "Unknown damage type or defense: #{invalid.inspect}" if invalid.any?

    freeze
  end

  def flag(type) = @flags[type.to_s]
  def to_h = @flags
  def immune_to?(type) = flag(type) == "I"
  def resistant_to?(type) = flag(type) == "R"
  def vulnerable_to?(type) = flag(type) == "V"
  def ==(other) = other.is_a?(self.class) && to_h == other.to_h

  # The damage after the defense: none for an immunity, halved (rounded down) for a resistance, doubled for a
  # vulnerability.
  def apply(amount, damage_type)
    case flag(damage_type)
    when "I" then 0
    when "R" then amount / 2
    when "V" then amount * 2
    else amount
    end
  end

  # The three columns written back: every damage type true/false, the other sections (conditions) untouched.
  def columns_for(combatant)
    FLAGS.to_h do |flag, column|
      [ column, combatant.public_send(column).merge("damage_types" => TYPES.index_with { |type| @flags[type] == flag }) ]
    end
  end
end
