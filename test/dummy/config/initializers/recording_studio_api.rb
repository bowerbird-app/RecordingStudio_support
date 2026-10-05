# frozen_string_literal: true

RecordingStudioApi.configure do |config|
  config.openapi_title = "Dummy host API"
  config.documentation_enabled = false
  config.api_management_authorization_required = false
  config.rate_limit_oauth_enabled = false
  config.rate_limit_api_pre_auth_enabled = false
  config.rate_limit_api_enabled = false
  config.rate_limit_fail_closed = false
  config.api_request_logging_enabled = false
end

# API 0.5.5 still reads the old Access integer-enum map. Accessible 0.11 stores
# role names as strings and no longer defines Access.roles.
Rails.application.config.to_prepare do
  next unless defined?(RecordingStudio::Access)
  next if RecordingStudio::Access.respond_to?(:roles)
  next unless defined?(RecordingStudio::AccessRoles::ORDER)

  RecordingStudio::Access.define_singleton_method(:roles) do
    RecordingStudio::AccessRoles::ORDER
  end
end
