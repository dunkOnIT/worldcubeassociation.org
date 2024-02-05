# frozen_string_literal: true

# TODO: Add validation to ensure that multiple accounts of the same type don't get added to CompetitionPaymentIntegration
class CompetitionPaymentIntegration < ApplicationRecord
  belongs_to :connected_account, polymorphic: true

  belongs_to :competition

  # enum available_integrations: {
  #   paypal: 'ConnectedPaypalAccount',
  # }

  AVAILABLE_INTEGRATIONS = {
    'paypal' => 'ConnectedPaypalAccount',
    'stripe' => 'ConnectedStripeAccount',
  }.freeze

  scope :paypal, -> { where(connected_account_type: 'ConnectedPaypalAccount') }
  scope :stripe, -> { where(connected_account_type: 'ConnectedStripeAccount') }

  def self.payments_enabled?(competition)
    competition.competition_payment_integrations.exists?
  end

  def self.account_for(competition, integration_name)
    competition.competition_payment_integrations.where(connected_account_type: AVAILABLE_INTEGRATIONS[integration_name])
  end

  def self.paypal_connected?(competition)
    competition.competition_payment_integrations.paypal.exists?
  end

  def self.stripe_connected?(competition)
    competition.competition_payment_integrations.stripe.exists?
  end

  # TODO: Add tests for case where integration isn't found
  def self.disconnect(competition, integration_name)
    raise ArgumentError.new("Invalid status. Allowed values are: #{AVAILABLE_INTEGRATIONS.keys.join(', ')}") unless
      AVAILABLE_INTEGRATIONS.keys.include?(integration_name)

    competition.competition_payment_integrations.destroy_by(connected_account_type: AVAILABLE_INTEGRATIONS[integration_name])
  end
end
