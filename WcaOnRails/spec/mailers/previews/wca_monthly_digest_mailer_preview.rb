# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/wca_monthly_digest_mailer
class WcaMonthlyDigestMailerPreview < ActionMailer::Preview
  def send_weat_digest_content
    mail = nil
    ActiveRecord::Base.transaction do
      mail = WcaMonthlyDigestMailer.send_weat_digest_content
    end
    mail
  end
end
