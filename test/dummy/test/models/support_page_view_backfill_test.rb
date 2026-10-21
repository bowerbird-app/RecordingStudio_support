# frozen_string_literal: true

require "test_helper"

class SupportPageViewBackfillTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "page-view-backfill-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    @root = RecordingStudio.root_recording_for(workspace)
    @section = record_support_section(@root, title: "Backfill #{SecureRandom.hex(4)}")
    @page = record_support_page(@root, @section, title: "Backfill article #{SecureRandom.hex(4)}")
  end

  test "copies page views into Views logs once and keeps actor and time" do
    occurred_at = Time.utc(2026, 4, 2, 15, 30, 0)
    page_view = nil
    travel_to(occurred_at) do
      page_view = RecordingStudioSupport::PageView.record!(recording: @page, actor: @user)
    end

    result = RecordingStudioSupport::PageViewBackfill.call

    copied = RecordingStudioViews::ViewLog.find(page_view.id)
    assert_equal 1, result.copied
    assert_equal @page.id, copied.recording_id
    assert_equal @root.id, copied.root_recording_id
    assert_equal "RecordingStudioSupport::SupportPage", copied.resource_type
    assert_equal "User", copied.actor_type
    assert_equal @user.id.to_s, copied.actor_id
    assert_equal occurred_at, copied.occurred_at
    assert_equal occurred_at, copied.created_at

    second = RecordingStudioSupport::PageViewBackfill.call
    assert_equal 0, second.copied
    assert_operator second.skipped, :>=, 1
    assert_equal 1, RecordingStudioViews::ViewLog.where(id: page_view.id).count
  end
end
