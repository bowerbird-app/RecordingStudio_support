# frozen_string_literal: true

module RecordingStudioSupport
  module CopyHelper
    def support_t(...)
      Copy.t(...)
    end

    def support_copy(override, key, **)
      Copy.value(override, key, **)
    end
  end
end
