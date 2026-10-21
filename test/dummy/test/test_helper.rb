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

  def record_help_view!(recording: nil, recording_id: nil, at: Time.current, actor: nil)
    attributes = RecordingStudioSupport::HelpPageViews.attributes_for(
      recording: recording,
      occurred_at: at,
      actor: actor
    )
    attributes[:recording_id] = recording_id if recording_id
    RecordingStudioViews::ViewLog.insert_all!([attributes])
    RecordingStudioViews::ViewLog.find(attributes[:id])
  end

  def ingest_help_view_from_page
    script = css_select("script[data-recording-studio-views-context]").first
    context = script ? JSON.parse(script.text) : {}
    event_id = SecureRandom.uuid
    token = css_select('meta[name="csrf-token"]').first
    post "/recording_studio_views/views",
         params: { event_id: event_id, token: context["token"], path: request.path.presence || "/" },
         as: :json,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "HTTP_ORIGIN" => "http://www.example.com",
           "HTTP_X_CSRF_TOKEN" => token ? token["content"] : ""
         }
    session = integration_session
    session.instance_variable_set(:@app, Rails.application)
    session.instance_variable_set(:@controller, nil)
    session.instance_variable_set(:@url_options, nil)
    RecordingStudioViews::ViewLog.find_by(id: event_id)
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
