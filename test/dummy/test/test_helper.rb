# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

module SupportRecordHelpers
  def record_support_section(root_recording, title: "Getting started")
    root_recording.record(RecordingStudioSupport::SupportSection) do |section|
      section.title = title
    end
  end

  def record_support_page(root_recording, section_recording, title:, body: "Body")
    root_recording.record(
      RecordingStudioSupport::SupportPage,
      parent_recording: section_recording
    ) do |page|
      page.title = title
      page.body = body
    end
  end

  def seeded_section(title)
    RecordingStudio::Recording.where(
      recordable_type: "RecordingStudioSupport::SupportSection",
      trashed_at: nil
    ).find { |recording| recording.recordable.title == title }
  end

  def seeded_page(title)
    RecordingStudio::Recording.where(
      recordable_type: "RecordingStudioSupport::SupportPage",
      trashed_at: nil
    ).find { |recording| recording.recordable.title == title }
  end
end

module ActiveSupport
  class TestCase
    include SupportRecordHelpers
  end
end

module ActionDispatch
  class IntegrationTest
    include SupportRecordHelpers

    def assert_flatpack_rounded_theme
      assert_select "html[data-theme='rounded']"
      assert_select "body[data-theme='rounded']"
    end
  end
end
