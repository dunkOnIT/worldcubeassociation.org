# frozen_string_literal: true

class CityValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if record.country.nil? || value.blank?

    if value == "Multiple cities"
      # This is a very special city name used for simultaneous FMC competitions
      # such as FMC USA. See https://github.com/thewca/worldcubeassociation.org/issues/3355.
      return
    end

    city_validator = self.class.get_validator_for_country(record.country.iso2)
    return unless city_validator

    reason_why_invalid = city_validator.reason_why_invalid(value)
    record.errors.add(attribute, reason_why_invalid) if reason_why_invalid
  end

  def self.get_validator_for_country(country_iso2)
    validator_for_country = CountryCityValidators::Utils::ALL_VALIDATORS.find do |validator|
      validator.country_iso_2 == country_iso2
    end

    validator_for_country&.new
  end
end
