# frozen_string_literal: true

# API 0.26 refuses a path that captures :id unless the endpoint passes
# recordable_type or scope_id: false. API 1.22 also refuses a non-GET
# endpoint that sets scope_id: false and omits required_role. Notifications
# 0.19.5 and Users 0.33 set required_role. This wrapper still marks sibling
# ids that are not recordings when a gem has not declared a scope.
module RecordingStudioApiSiblingScope
  module_function

  SIBLING_ENDPOINT = /\A(notifications\.|messages_|users_)/
  RECORDING_ID = /:(?:id|recording_id)(?:\/|\z)/

  def install!
    return if RecordingStudioApi.respond_to?(:register_endpoint_without_sibling_scope)

    RecordingStudioApi.singleton_class.alias_method(
      :register_endpoint_without_sibling_scope,
      :register_endpoint
    )

    RecordingStudioApi.define_singleton_method(:register_endpoint) do |name, path:, recordable_type: nil, scope_id: nil, **kwargs|
      if RecordingStudioApiSiblingScope.unscoped_id?(name, path, recordable_type, scope_id)
        scope_id = false
      end

      register_endpoint_without_sibling_scope(
        name,
        path: path,
        recordable_type: recordable_type,
        scope_id: scope_id,
        **kwargs
      )
    end
  end

  def unscoped_id?(name, path, recordable_type, scope_id)
    return false unless scope_id.nil? && recordable_type.nil?
    return false unless name.to_s.match?(SIBLING_ENDPOINT)

    path.to_s.match?(RECORDING_ID)
  end
end

RecordingStudioApiSiblingScope.install!
