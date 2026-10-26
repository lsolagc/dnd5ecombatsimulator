class Combatant < ApplicationRecord
  include AbilityScores
  include ConditionAndDamageTypeLogic

  DEFENSE_NAMES = { "immunities" => "imunidade", "resistances" => "resistência", "vulnerabilities" => "vulnerabilidade" }.freeze

  delegated_type :combatable, types: %w[ PlayerCharacter ]

  has_ability_score_modifiers

  validates :damage_type, inclusion: { in: ConditionAndDamageTypeFormatValidator::EXPECTED_STRUCTURE["damage_types"] }
  validate :one_defense_per_damage_type

  def defenses = Defenses.of(self)

  # defenses: a Combatant::Defenses or its { damage type => flag } hash.
  def defenses=(defenses)
    assign_attributes(Defenses.new(defenses).columns_for(self))
  end

  private
    def one_defense_per_damage_type
      Defenses::TYPES.each do |type|
        columns = Defenses::FLAGS.values.select { |column| defended?(public_send(column), type) }
        next if columns.size < 2

        names = columns.map { |column| DEFENSE_NAMES[column] }.to_sentence(two_words_connector: " e ", last_word_connector: " e ")
        errors.add(:base, "Um tipo de dano tem uma defesa só (#{type}: #{names})")
      end
    end

    # Tolerates a malformed column (the format validator reports it).
    def defended?(column_value, type)
      column_value.is_a?(Hash) && column_value["damage_types"].is_a?(Hash) && column_value["damage_types"][type] == true
    end
end
