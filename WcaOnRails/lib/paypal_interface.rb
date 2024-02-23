# frozen_string_literal: true

module PaypalInterface
  # Defined in: https://developer.paypal.com/docs/reports/reference/paypal-supported-currencies/
  PAYPAL_CURRENCY_CATEGORIES = {
    decimal: [ # Currencies that should be passed to paypal as decimal amounts (ie, cents/100)
      "AUD",
      "BRL",
      "CAD",
      "CNY",
      "CZK",
      "DKK",
      "EUR",
      "HKD",
      "ILS",
      "MYR",
      "MXN",
      "NZD",
      "NOK",
      "PHP",
      "PLN",
      "GBP",
      "SGD",
      "SEK",
      "CHF",
      "THB",
      "USD",
    ],
    cents_only: [ # Currencies that do not support decimals - should be passed as cents
      "JPY",
      "HUF",
      "TWD",
    ],
  }.freeze

  def self.generate_paypal_onboarding_link(competition_id)
    url = "#{EnvConfig.PAYPAL_BASE_URL}/v2/customer/partner-referrals"

    payload = {
      operations: [
        {
          operation: 'API_INTEGRATION',
          api_integration_preference: {
            rest_api_integration: {
              integration_method: 'PAYPAL',
              integration_type: 'THIRD_PARTY',
              third_party_details: {
                features: ['PAYMENT', 'REFUND'],
              },
            },
          },
        },
      ],
      products: ['PPCP'], # TODO: Experiment with other payment types
      partner_config_override: {
        return_url: EnvConfig.ROOT_URL + Rails.application.routes.url_helpers.competitions_paypal_return_path(competition_id),
        return_url_description: "the url to return the WCA after the paypal onboarding process.",
      },
      legal_consents: [
        {
          type: 'SHARE_DATA_CONSENT',
          granted: true,
        },
      ],
    }

    response = paypal_connection(url).post do |req|
      req.body = payload
    end

    response.body['links'].each do |link|
      if link['rel'] == "action_url"
        return link['href']
      end
    end
  end

  def self.create_order(registration, outstanding_fees, fee_currency)
    url = "#{EnvConfig.PAYPAL_BASE_URL}/v2/checkout/orders"

    amount = PaypalTransaction.get_paypal_amount(outstanding_fees, fee_currency)

    payload = {
      intent: 'CAPTURE',
      purchase_units: [
        {
          amount: { currency_code: fee_currency, value: amount },
        },
      ],
    }

    response = paypal_connection(url).post do |req|
      req.headers['PayPal-Partner-Attribution-Id'] = AppSecrets.PAYPAL_ATTRIBUTION_CODE
      req.headers['PayPal-Auth-Assertion'] = get_paypal_auth_assertion(registration.competition)

      req.body = payload
    end

    body = response.body

    PaypalTransaction.create(
      order_id: body["id"],
      status: body["status"],
      payload: payload,
      amount_in_cents: outstanding_fees,
      currency_code: fee_currency,
    )

    body
  end

  # TODO: Update the status of the PaypalTransaction object?
  def self.capture_payment(competition, order_id)
    url = "#{EnvConfig.PAYPAL_BASE_URL}/v2/checkout/orders/#{order_id}/capture"

    response = paypal_connection(url).post do |req|
      req.headers['PayPal-Partner-Attribution-Id'] = AppSecrets.PAYPAL_ATTRIBUTION_CODE
      req.headers['PayPal-Auth-Assertion'] = get_paypal_auth_assertion(competition)
    end

    response.body
  end

  # def self.paypal_amount(amount_in_cents, currency_code)
  #   if PAYPAL_CURRENCY_CATEGORIES[:decimal].include?(currency_code)
  #     format("%.2f", amount_in_cents.to_i / 100.0)
  #   else
  #     amount_in_cents
  #   end
  # end

  private_class_method def self.paypal_connection(url)
    Faraday.new(
      url: url,
      headers: {
        'Authorization' => "Bearer #{generate_access_token}",
        'Content-Type' => 'application/json',
      },
    ) do |builder|
      # Sets headers and parses jsons automatically
      builder.request :json
      builder.response :json

      # Raises an error on 4xx and 5xx responses.
      builder.response :raise_error

      # Logs requests and responses.
      # By default, it only logs the request method and URL, and the request/response headers.
      builder.response :logger, ::Logger.new($stdout), bodies: true
    end
  end

  private_class_method def self.generate_access_token
    options = {
      site: EnvConfig.PAYPAL_BASE_URL,
      token_url: '/v1/oauth2/token',
    }

    client = OAuth2::Client.new(AppSecrets.PAYPAL_CLIENT_ID, AppSecrets.PAYPAL_CLIENT_SECRET, options)
    client.client_credentials.get_token.token
  end

  private_class_method def self.get_paypal_auth_assertion(competition)
    payload = { "iss" => AppSecrets.PAYPAL_CLIENT_ID, "payer_id" => competition.payment_account_for(:paypal).paypal_merchant_id }
    JWT.encode payload, nil, 'none'
  end
end
