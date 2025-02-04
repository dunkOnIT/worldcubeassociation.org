# frozen_string_literal: true

class RegistrationPayment < ApplicationRecord
  belongs_to :registration
  belongs_to :user

  belongs_to :receipt, polymorphic: true, optional: true

  belongs_to :refunded_registration_payment, class_name: 'RegistrationPayment', optional: true
  has_many :refunding_registration_payments, class_name: 'RegistrationPayment', inverse_of: :refunded_registration_payment, foreign_key: :refunded_registration_payment_id, dependent: :destroy

  after_create :attempt_auto_close

  monetize :amount_lowest_denomination,
           as: "amount",
           allow_nil: true,
           with_model_currency: :currency_code

  def amount_available_for_refund
    amount_lowest_denomination + refunding_registration_payments.sum(:amount_lowest_denomination)
  end

  def payment_status
    case receipt.stripe_record_type
    when "refund"
      "refund"
    else
      receipt.determine_wca_status
    end
  end

  private def attempt_auto_close
    registration.competition.auto_close
  end
end
