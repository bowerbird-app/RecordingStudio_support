# frozen_string_literal: true

module RecordingStudioSupport
  module Api
    class Search
      module Token
        module_function

        def offset(params)
          token = params[:pagination_token].presence || params["pagination_token"].presence
          return 0 if token.blank?

          decode(token)
        end

        def encode(offset)
          verifier.generate({ "o" => offset }, purpose: TOKEN_PURPOSE)
        end

        def decode(token)
          payload = verifier.verify(token.to_s, purpose: TOKEN_PURPOSE)
          value = payload.is_a?(Hash) ? payload["o"] : nil
          return value if value.is_a?(Integer) && value >= 0

          raise invalid_token
        rescue ActiveSupport::MessageVerifier::InvalidSignature, TypeError
          raise invalid_token
        end

        def verifier
          Rails.application.message_verifier(TOKEN_PURPOSE)
        end

        def invalid_token
          RecordingStudioApi::InvalidPaginationTokenError.new("Invalid pagination token")
        end
      end
    end
  end
end
