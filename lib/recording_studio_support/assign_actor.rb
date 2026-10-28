# frozen_string_literal: true

module RecordingStudioSupport
  module AssignActor
    def assign_actor(actor)
      return yield if actor.nil? || !defined?(Current)

      previous = Current.actor
      Current.actor = actor
      yield
    ensure
      Current.actor = previous if defined?(Current) && !actor.nil?
    end
    module_function :assign_actor
  end
end
