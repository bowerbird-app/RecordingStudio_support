# frozen_string_literal: true

module RecordingStudioSupport
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
