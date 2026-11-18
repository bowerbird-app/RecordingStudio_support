# frozen_string_literal: true

require "test_helper"

class OperationDocsTest < Minitest::Test
  Docs = RecordingStudioSupport::Api::OperationDocs
  Page = RecordingStudioSupport::Api::PAGE_TYPE
  Section = RecordingStudioSupport::Api::SECTION_TYPE
  Center = RecordingStudioSupport::Api::CENTER_TYPE
  Ticket = RecordingStudioSupport::Api::TICKET_TYPE

  def test_operation_titles_are_action_first
    assert_equal "List support pages", Docs.operation_title(Page, :index)
    assert_equal "Show support page", Docs.operation_title(Page, :show)
    assert_equal "Create support page", Docs.operation_title(Page, :create)
    assert_equal "Update support page", Docs.operation_title(Page, :update)
    assert_equal "Trash support page", Docs.operation_title(Page, :destroy)
    assert_equal "List support sections", Docs.operation_title(Section, :index)
    assert_equal "Show support section", Docs.operation_title(Section, :show)
    assert_equal "Create support section", Docs.operation_title(Section, :create)
    assert_equal "Update support section", Docs.operation_title(Section, :update)
    assert_equal "Trash support section", Docs.operation_title(Section, :destroy)
    assert_equal "List support centers", Docs.operation_title(Center, :index)
    assert_equal "Show support center", Docs.operation_title(Center, :show)
    assert_equal "Create support center", Docs.operation_title(Center, :create)
    assert_equal "List support tickets", Docs.operation_title(Ticket, :index)
    assert_equal "Show support ticket", Docs.operation_title(Ticket, :show)
    assert_equal "Open support ticket", Docs.operation_title(Ticket, :create)
    assert_equal "Update support ticket", Docs.operation_title(Ticket, :update)
  end

  def test_capability_titles_name_the_action_before_the_record
    assert_equal "Move support page", Docs.capability_title(Page, :move)
    assert_equal "Publish support page", Docs.capability_title(Page, :publish)
    assert_equal "Unpublish support page", Docs.capability_title(Page, :unpublish)
    assert_equal "Update support page publishing", Docs.capability_title(Page, :update_publishable)
    assert_equal "Trash support page", Docs.capability_title(Page, :trashable_trash)
    assert_equal "Restore support page", Docs.capability_title(Page, :trashable_restore)
    assert_equal "Purge support trash", Docs.capability_title(Page, :trashable_purge)
    assert_equal "List support trash", Docs.capability_title(Page, :trashable_list_trash_bin)
    assert_equal "Reorder support section", Docs.capability_title(Section, :reorder)
    assert_equal "Move page in support section", Docs.capability_title(Section, :move_position)
    assert_equal "Trash support section", Docs.capability_title(Section, :trashable_trash)
    assert_equal "Restore support section", Docs.capability_title(Section, :trashable_restore)
    assert_equal "Purge support trash", Docs.capability_title(Section, :trashable_purge)
    assert_equal "List support trash", Docs.capability_title(Section, :trashable_list_trash_bin)
    assert_equal "List support center access", Docs.capability_title(Center, :list_access)
    assert_equal "Grant support center access", Docs.capability_title(Center, :grant_access)
    assert_equal "Update support center access", Docs.capability_title(Center, :update_access)
    assert_equal "Revoke support center access", Docs.capability_title(Center, :revoke_access)
    assert_nil Docs.capability_title(Ticket, :publish)
    refute_includes Docs.capability_titles.values.flat_map(&:values), "Publish press kit"
  end

  def test_trash_actions_use_the_mcp_tag_suffix
    assert_equal "Trash", Docs::TRASH_SUFFIX
    refute File.exist?(File.expand_path("../lib/recording_studio_support/api/mcp_docs.rb", __dir__))
  end

  def test_registration_copy_keeps_the_support_group_and_sets_titles
    copy = Docs.for(Page, operations: %i[index show destroy])

    assert_equal ["Support"], copy.fetch(:tags)
    assert_equal "Support", copy.dig(:tag, :group)

    public_page = Docs.for(
      Page,
      operations: %i[index show],
      openapi: RecordingStudioSupport::Api::PUBLIC_PAGE_OPENAPI
    )
    assert_equal ["Support Page"], public_page.fetch(:tags)
    assert_equal "Support", public_page.dig(:tag, :group)
    assert_equal "List support pages", public_page.dig(:index, :title)
    assert_equal "Show support page", public_page.dig(:show, :title)
    assert_equal "List support pages", copy.dig(:index, :title)
    assert_equal "List support pages", copy.dig(:index, :summary)
    assert_equal "Trash support page", copy.dig(:destroy, :title)
    assert_equal "Moves this support page to the trash.", copy.dig(:destroy, :description)
    assert_nil copy[:create]
  end
end
