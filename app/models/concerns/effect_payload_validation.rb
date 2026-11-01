require "active_support/concern"

# Validates effect_payload against ClassFeatureUnlock::EFFECT_KINDS: .okf/models/class-feature-unlock.md (Effect vocabulary)
module EffectPayloadValidation
  extend ActiveSupport::Concern

  included do
    validate :effect_payload_fits_its_kind, if: -> { effect_payload.present? }
  end

  private

    def effect_payload_fits_its_kind
      payload = effect_payload.deep_stringify_keys
      spec = ClassFeatureUnlock::EFFECT_KINDS[payload["kind"]]
      return errors.add(:effect_payload, "has an unknown kind: #{payload['kind'].inspect}") if spec.nil?

      field_problems(payload.except("kind"), spec[:required], spec.fetch(:optional, {})).each { errors.add(:effect_payload, it) }
    end

    def field_problems(fields, required, optional, path = nil)
      name = ->(key) { [ path, key ].compact.join(".") }
      missing = (required.keys - fields.keys).map { "is missing #{name.(it)}" }
      unknown = (fields.keys - required.keys - optional.keys).map { "has an unknown field #{name.(it)}" }
      invalid = fields.flat_map { |key, value| value_problems(value, required.fetch(key) { optional[key] }, name.(key)) }
      missing + unknown + invalid
    end

    def value_problems(value, accepted, label)
      case accepted
      in [ Hash => item ]
        return [ "#{label} must be a list" ] unless value.is_a?(Array)

        value.each_with_index.flat_map { |element, index| value_problems(element, item, "#{label}[#{index}]") }
      in [ Range => range, *words ]
        value_problems(value, range, label).empty? || words.include?(value) ? [] : [ "#{label} must be #{integer_in(range)} or #{words.join(', ')}" ]
      in Hash then value.is_a?(Hash) ? field_problems(value.stringify_keys, accepted, {}, label) : [ "#{label} must be an object" ]
      in Array then accepted.include?(value) ? [] : [ "#{label} must be one of #{accepted.join(', ')}" ]
      in Class then value.is_a?(accepted) ? [] : [ "#{label} must be of type #{accepted.name.downcase}" ]
      in Range then value.is_a?(Integer) && accepted.cover?(value) ? [] : [ "#{label} must be #{integer_in(accepted)}" ]
      else []
      end
    end

    def integer_in(range)
      range.end ? "an integer from #{range.begin} to #{range.end}" : "an integer of at least #{range.begin}"
    end
end
