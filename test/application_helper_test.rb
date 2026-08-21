# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < Minitest::Test
  def test_support_page_updated_on_uses_the_publish_day
    helper = Object.new.extend(load_helper)

    assert_nil helper.support_page_updated_on(nil)
    assert_equal "Updated August 21, 2026", helper.support_page_updated_on(Time.utc(2026, 8, 21, 15, 30))
  end

  def test_support_publish_path_is_blank_without_routes
    helper = Object.new.extend(load_helper)

    assert_nil helper.support_publish_path(nil)
    assert_nil helper.support_publish_path(Object.new)
  end

  def test_public_pages_controller_uses_publishable_chrome
    source = File.read(File.expand_path("../app/controllers/recording_studio_support/public_pages_controller.rb", __dir__))

    assert_includes source, "skip_before_action :authenticate_user!"
    assert_includes source, 'layout "recording_studio_publishable/application"'
    assert_includes source, "Pages.public_indexable"
    assert_includes source, "@publishable&.publish_at"
  end

  private

  def load_helper
    path = File.expand_path("../app/helpers/recording_studio_support/application_helper.rb", __dir__)
    require path
    RecordingStudioSupport::ApplicationHelper
  end
end
