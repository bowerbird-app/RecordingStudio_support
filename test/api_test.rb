# frozen_string_literal: true

require "test_helper"

class ApiTest < Minitest::Test
  def test_registration_is_a_noop_without_recording_studio_api
    refute Object.const_defined?(:RecordingStudioApi, false)
    assert_nil RecordingStudioSupport::Api.register!
  end

  def test_support_types_are_section_and_page
    assert_equal "RecordingStudioSupport::SupportSection", RecordingStudioSupport::Api::SECTION_TYPE
    assert_equal "RecordingStudioSupport::SupportPage", RecordingStudioSupport::Api::PAGE_TYPE
    assert RecordingStudioSupport::Api.support_type?("RecordingStudioSupport::SupportPage")
    refute RecordingStudioSupport::Api.support_type?("Workspace")
  end

  def test_write_handlers_use_pages_and_sections_helpers
    create = File.read(File.expand_path("../lib/recording_studio_support/api/create.rb", __dir__))
    update = File.read(File.expand_path("../lib/recording_studio_support/api/update.rb", __dir__))
    destroy = File.read(File.expand_path("../lib/recording_studio_support/api/destroy.rb", __dir__))
    move = File.read(File.expand_path("../lib/recording_studio_support/api/move.rb", __dir__))
    access = File.read(File.expand_path("../lib/recording_studio_support/api/access.rb", __dir__))

    assert_includes create, "Sections.create!"
    assert_includes create, "Pages.create!"
    assert_includes update, "Sections.revise!"
    assert_includes update, "Pages.revise!"
    assert_includes destroy, "Sections.trash!"
    assert_includes destroy, "Pages.trash!"
    assert_includes move, "Pages.move!"
    assert_includes access, "authorize_edit!"
    refute_includes create, "Recording.create!"
    refute_includes update, "Recording.create!"
    refute_includes destroy, "recording.destroy!"
  end

  def test_writes_authorize_admin_root_edit
    access = File.read(File.expand_path("../lib/recording_studio_support/api/access.rb", __dir__))
    create = File.read(File.expand_path("../lib/recording_studio_support/api/create.rb", __dir__))
    move = File.read(File.expand_path("../lib/recording_studio_support/api/move.rb", __dir__))

    assert_includes access, "admin_root_recording"
    assert_includes access, "RecordingStudioAccessible.authorized?"
    assert_includes access, "authorized_on_admin_root?(context, :edit)"
    assert_includes create, "Access.authorize_edit!"
    assert_includes move, "Access.authorize_edit!"
    refute_includes access, "user.admin?"
  end

  def test_engine_registers_api_when_present
    engine = File.read(File.expand_path("../lib/recording_studio_support/engine.rb", __dir__))
    api = File.read(File.expand_path("../lib/recording_studio_support/api.rb", __dir__))

    assert_includes engine, 'initializer "recording_studio_support.api"'
    assert_includes engine, "RecordingStudioSupport::Api.register!"
    assert_includes api, "RecordingStudioApi.register_recordable_type_api"
    assert_includes api, "Intercept::Create"
    assert_includes api, "ResourcesLookup"
    assert_includes api, "MemberActionsLookup"
  end

  def test_gemspec_still_omits_api_dependency
    gemspec = File.read(File.expand_path("../recording_studio_support.gemspec", __dir__))

    refute_includes gemspec, 'spec.add_dependency "recording_studio_api"'
  end
end
