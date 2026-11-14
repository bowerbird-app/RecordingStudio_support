# frozen_string_literal: true

require "test_helper"

class TrashableSiblingParityTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "trashable-parity-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @user
    @admin_root, @center = admin_support_tree(@user)
    @root_recording = @admin_root
  end

  teardown do
    Current.actor = nil
    remove_recording_default_scope!
  end

  test "kept page and section scopes match Recording.kept" do
    section = record_support_section(@root_recording, title: "Live section")
    kept_page = record_support_page(@root_recording, section, title: "Kept page")
    trashed_page = record_support_page(@root_recording, section, title: "Trashed page")
    trashed_page.recording_studio_trashable_trash!(actor: @user)

    other_section = record_support_section(@root_recording, title: "Gone section")
    other_section.recording_studio_trashable_trash!(actor: @user)

    page_ids = RecordingStudioSupport::Pages.kept_pages(@root_recording).pluck(:id)
    section_ids = RecordingStudioSupport::Sections.kept_sections(@center).pluck(:id)
    main_page_ids = RecordingStudio::Recording.kept.where(
      root_recording_id: @root_recording.id,
      recordable_type: RecordingStudioSupport::Pages::SUPPORT_PAGE_TYPE
    ).pluck(:id)
    main_section_ids = RecordingStudio::Recording.kept.where(
      parent_recording_id: @center.id,
      recordable_type: RecordingStudioSupport::Sections::SUPPORT_SECTION_TYPE
    ).pluck(:id)

    assert_equal main_page_ids.sort, page_ids.sort
    assert_equal main_section_ids.sort, section_ids.sort
    assert_includes page_ids, kept_page.id
    assert_not_includes page_ids, trashed_page.id
    assert_includes section_ids, section.id
    assert_not_includes section_ids, other_section.id

    assert kept_page.recording_studio_trashable_kept?
    assert trashed_page.reload.recording_studio_trashable_trashed?
  end

  test "kept scopes use Recording.kept and not trashable query helpers" do
    %i[kept_sections kept kept_page_recordings kept_pages].each do |name|
      source_file = case name
                    when :kept_sections, :kept
                      RecordingStudioSupport::Sections.method(name).source_location.first
                    when :kept_page_recordings
                      RecordingStudioSupport::Admin::Queries.method(name).source_location.first
                    else
                      RecordingStudioSupport::Pages.method(name).source_location.first
                    end
      code = File.read(source_file).lines.grep_v(/^\s*#/).join
      assert_includes code, "RecordingStudio::Recording.kept", "#{name} source must use Recording.kept"
      assert_not_includes code, "trashed_at: nil", "#{name} source must not hand-write trashed_at: nil"
      assert_not_includes code, "recording_studio_trashable_active",
                          "#{name} source must not use trashable_active"
      assert_not_includes code, "recording_studio_trashable_kept_sql"
    end
  end

  test "section slug join uses kept_sql quotes tables and ignores trashed section slugs" do
    table = RecordingStudio::Recording.table_name
    quoted_table = ActiveRecord::Base.connection.quote_table_name(table)
    quoted_sections = ActiveRecord::Base.connection.quote_table_name(
      RecordingStudioSupport::SupportSection.table_name
    )
    expected_kept = RecordingStudio.kept_sql(table)
    join_sql = RecordingStudioSupport::SupportSection.current_kept_join_sql

    assert_includes join_sql, expected_kept
    assert_includes join_sql, "INNER JOIN #{quoted_table}"
    assert_includes join_sql, "#{quoted_table}.recordable_id = #{quoted_sections}.id"
    assert_no_match(/INNER JOIN #{Regexp.escape(table)} /, join_sql)

    title = "Parity billing #{SecureRandom.hex(4)}"
    expected_slug = title.parameterize
    live = record_support_section(@root_recording, title: title)
    assert_equal expected_slug, live.recordable.slug

    live.recording_studio_trashable_trash!(actor: @user)
    assert_not RecordingStudioSupport::SupportSection.slug_taken?(expected_slug),
               "trashed section slug should be free via kept_sql join"

    reused = record_support_section(@root_recording, title: title)
    assert_equal expected_slug, reused.recordable.slug
  end

  test "api workspace lookup rejects trashed roots with main additive filter" do
    assert_equal @center.id, RecordingStudioSupport::Api::Lookup.workspace!(id: @center.id).id

    RecordingStudioTrashable.void_recording!(@center, time: Time.current)
    assert @center.reload.recording_studio_trashable_trashed?

    error = assert_raises(RecordingStudioApi::NotFoundError) do
      RecordingStudioSupport::Api::Lookup.workspace!(id: @center.id)
    end
    assert_equal "Parent resource was not found", error.message
  ensure
    @center = record_support_center(@admin_root)
  end

  test "admin kept page recordings exclude trashed rows" do
    section = record_support_section(@root_recording, title: "Docs")
    kept = record_support_page(@root_recording, section, title: "Kept admin page")
    trashed = record_support_page(@root_recording, section, title: "Trashed admin page")
    trashed.recording_studio_trashable_trash!(actor: @user)

    ids = RecordingStudioSupport::Admin::Queries.kept_page_recordings.pluck(:id)
    assert_includes ids, kept.id
    assert_not_includes ids, trashed.id
  end

  test "kept matches Recording.kept under a host default scope and does not unscope" do
    section = record_support_section(@root_recording, title: "Default scope section")
    kept_page = record_support_page(@root_recording, section, title: "Default scope kept")
    trashed_page = record_support_page(@root_recording, section, title: "Default scope trashed")
    trashed_page.recording_studio_trashable_trash!(actor: @user)

    install_recording_default_scope!

    kept_pages = RecordingStudioSupport::Pages.kept_pages(@root_recording)
    kept_sections = RecordingStudioSupport::Sections.kept_sections(@center)

    main_ids = RecordingStudio::Recording.kept.where(
      root_recording_id: @root_recording.id,
      recordable_type: RecordingStudioSupport::Pages::SUPPORT_PAGE_TYPE
    ).pluck(:id)
    support_ids = kept_pages.pluck(:id)
    section_main_ids = RecordingStudio::Recording.kept.where(
      parent_recording_id: @center.id,
      recordable_type: RecordingStudioSupport::Sections::SUPPORT_SECTION_TYPE
    ).pluck(:id)
    section_support_ids = kept_sections.pluck(:id)

    assert_equal main_ids.sort, support_ids.sort
    assert_equal section_main_ids.sort, section_support_ids.sort
    assert_includes support_ids, kept_page.id
    assert_not_includes support_ids, trashed_page.id
    assert_includes section_support_ids, section.id

    # .kept adds the registered filter. It does not unscope, so a trashed-only
    # relation stays trashed-only.
    trashed_base = RecordingStudio::Recording.unscope(where: :trashed_at).where.not(trashed_at: nil).where(
      root_recording_id: @root_recording.id,
      recordable_type: RecordingStudioSupport::Pages::SUPPORT_PAGE_TYPE
    )
    assert_not_includes trashed_base.kept.pluck(:id), kept_page.id
    assert_empty trashed_base.where(trashed_at: nil).pluck(:id)
  end

  private

  def install_recording_default_scope!
    return if @default_scope_installed

    RecordingStudio::Recording.class_eval do
      default_scope -> { where(trashed_at: nil) }
    end
    @default_scope_installed = true
  end

  def remove_recording_default_scope!
    return unless @default_scope_installed

    RecordingStudio::Recording.default_scopes.clear
    @default_scope_installed = false
  end

end
