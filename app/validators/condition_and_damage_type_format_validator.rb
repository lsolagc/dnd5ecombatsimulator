class ConditionAndDamageTypeFormatValidator < ActiveModel::EachValidator
  EXPECTED_STRUCTURE = {
    "conditions" => %w[
      blindness charm deafness fear grapple incapacitation invisibility paralysis
      petrification poisoning prone restraint stun unconsciousness exhaustion
    ],
    "damage_types" => %w[
      acid bludgeoning cold fire force lightning necrotic piercing
      poison psychic radiant slashing thunder
    ]
  }.freeze

  def validate_each(record, attribute, value)
    unless value.is_a?(Hash)
      record.errors.add(attribute, :not_a_hash)
      return
    end

    EXPECTED_STRUCTURE.each do |section, keys|
      unless value[section].is_a?(Hash)
        record.errors.add(attribute, :invalid_section, section: section)
        next
      end

      keys.each do |key|
        unless value[section].key?(key)
          record.errors.add(attribute, :missing_key, key: key, section: section)
          next
        end

        val = value[section][key]
        unless [ true, false ].include?(val)
          record.errors.add(attribute, :invalid_value, key: key, section: section)
        end
      end
    end
  end
end
