# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

module SupportRecordHelpers
  def record_support_center(parent_recording)
    center = RecordingStudioSupport::SupportCenters.for_parent(parent_recording) ||
      parent_recording.record(RecordingStudioSupport::SupportCenter)
    grant_center_access!(center, Current.actor)
    center
  end

  def grant_center_access!(center, actor)
    return if actor.blank? || center.blank?

    grant_role!(center, actor, :admin)
    parent = center.parent_recording || center.root_recording
    grant_role!(parent, actor, :admin) if parent && parent != center
  end

  def admin_support_tree(actor = Current.actor)
    admin = RecordingStudio.root_recording_for(AdminRoot.find_or_create_by!(name: "Admin"))
    grant_role!(admin, actor, :admin) if actor
    center = record_support_center(admin)
    [admin, center]
  end

  def record_support_section(root_recording, title: "Getting started")
    center = support_center_for(root_recording)
    (center.root_recording || center).record(
      RecordingStudioSupport::SupportSection,
      parent_recording: center
    ) do |section|
      section.title = title
    end
  end

  def support_center_for(recording)
    return recording if recording.recordable_type == "RecordingStudioSupport::SupportCenter"
    if recording.recordable_type == RecordingStudioSupport.parent_root_type
      return record_support_center(recording)
    end

    admin = RecordingStudio.root_recording_for(AdminRoot.find_or_create_by!(name: "Admin"))
    record_support_center(admin)
  end

  def record_support_page(root_recording, section_recording, title:, body: "Body")
    root = section_recording.root_recording || root_recording
    root.record(
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
           "HTTP_X_CSRF_TOKEN" => token ? token["content"] : "",
           "HTTP_USER_AGENT" => "Mozilla/5.0 Chrome/120.0"
         }
    session = integration_session
    session.instance_variable_set(:@app, Rails.application)
    session.instance_variable_set(:@controller, nil)
    session.instance_variable_set(:@url_options, nil)
    RecordingStudioViews::ViewLog.find_by(id: event_id)
  end

  def revise_support_ticket!(ticket, **changes)
    RecordingStudioSupport::Tickets.update!(ticket, actor: Current.actor, **changes)
    RecordingStudioSupport::Tickets.find!(ticket.id)
  end

  def grant_admin!(recording, actor)
    grant_role!(recording, actor, :admin)
  end

  def grant_role!(recording, actor, role)
    return if recording.blank? || actor.blank?

    held = RecordingStudioAccessible.role_for(actor: actor, recording: recording).to_s
    wanted = role.to_s
    return if held == wanted
    return if held == "admin"

    if wanted == "admin"
      result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
      return if result.success?
      unless already_granted?(result)
        raise result.error if result.failure?
        return
      end
    end

    owner = owner_for_grant(recording, actor)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role,
      manager_actor: owner
    )
    return if result.success? || already_granted?(result)

    raise result.error
  end

  def already_granted?(result)
    result.failure? && result.error.to_s.match?(/already exists|already granted/i)
  end

  def owner_for_grant(recording, actor)
    existing = existing_admin_actor(recording)
    return existing if existing

    admin = User.find_by(email: "admin@admin.com")
    bootstrap_actor = [admin, actor].compact.find do |candidate|
      RecordingStudioAccessible.role_for(actor: candidate, recording: recording).to_s == "admin"
    end
    return bootstrap_actor if bootstrap_actor

    bootstrap_actor = admin || actor
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: bootstrap_actor)
    unless result.success? || already_granted?(result)
      raise result.error
    end
    existing_admin_actor(recording) || bootstrap_actor
  end

  def existing_admin_actor(recording)
    RecordingStudioAccessible.access_recordings_for(recording).each do |access_recording|
      recordable = access_recording.recordable
      next unless recordable&.role.to_s == "admin"

      found = recordable.actor
      return found if found
    end
    nil
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
    end
  end
end
