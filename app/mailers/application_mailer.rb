class ApplicationMailer < ActionMailer::Base
  # Set MAIL_FROM to an address your SMTP provider has verified.
  default from: ENV.fetch("MAIL_FROM", "FixFlow <no-reply@fixflow.test>")
  layout "mailer"
end
