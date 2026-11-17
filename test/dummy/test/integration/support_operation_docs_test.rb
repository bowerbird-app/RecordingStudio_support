# frozen_string_literal: true

require "test_helper"

class SupportOperationDocsTest < ActiveSupport::TestCase
  PAGE = "RecordingStudioSupport::SupportPage"
  SECTION = "RecordingStudioSupport::SupportSection"
  CENTER = "RecordingStudioSupport::SupportCenter"
  TICKET = "RecordingStudioSupport::SupportTicket"
  TRASH = "Support Trash"
  SUPPORT = "Support"

  EXPECTED = {
    [:public, PAGE, :index] => [SUPPORT, "List support pages"],
    [:public, PAGE, :show] => [SUPPORT, "Show support page"],
    [:public, PAGE, :move] => [SUPPORT, "Move support page"],
    [:public, PAGE, :publish] => [SUPPORT, "Publish support page"],
    [:public, PAGE, :unpublish] => [SUPPORT, "Unpublish support page"],
    [:public, PAGE, :update_publishable] => [SUPPORT, "Update support page publishing"],
    [:public, PAGE, :trashable_trash] => [TRASH, "Trash support page"],
    [:public, PAGE, :trashable_restore] => [TRASH, "Restore support page"],
    [:public, PAGE, :trashable_purge] => [TRASH, "Purge support trash"],
    [:public, PAGE, :trashable_list_trash_bin] => [TRASH, "List support trash"],
    [:public, TICKET, :index] => [SUPPORT, "List support tickets"],
    [:public, TICKET, :show] => [SUPPORT, "Show support ticket"],
    [:public, TICKET, :create] => [SUPPORT, "Open support ticket"],
    [:operations, PAGE, :index] => [SUPPORT, "List support pages"],
    [:operations, PAGE, :show] => [SUPPORT, "Show support page"],
    [:operations, PAGE, :create] => [SUPPORT, "Create support page"],
    [:operations, PAGE, :update] => [SUPPORT, "Update support page"],
    [:operations, PAGE, :destroy] => [SUPPORT, "Trash support page"],
    [:operations, PAGE, :move] => [SUPPORT, "Move support page"],
    [:operations, PAGE, :publish] => [SUPPORT, "Publish support page"],
    [:operations, PAGE, :unpublish] => [SUPPORT, "Unpublish support page"],
    [:operations, PAGE, :update_publishable] => [SUPPORT, "Update support page publishing"],
    [:operations, PAGE, :trashable_trash] => [TRASH, "Trash support page"],
    [:operations, PAGE, :trashable_restore] => [TRASH, "Restore support page"],
    [:operations, PAGE, :trashable_purge] => [TRASH, "Purge support trash"],
    [:operations, PAGE, :trashable_list_trash_bin] => [TRASH, "List support trash"],
    [:operations, SECTION, :index] => [SUPPORT, "List support sections"],
    [:operations, SECTION, :show] => [SUPPORT, "Show support section"],
    [:operations, SECTION, :create] => [SUPPORT, "Create support section"],
    [:operations, SECTION, :update] => [SUPPORT, "Update support section"],
    [:operations, SECTION, :destroy] => [SUPPORT, "Trash support section"],
    [:operations, SECTION, :reorder] => [SUPPORT, "Reorder support section"],
    [:operations, SECTION, :move_position] => [SUPPORT, "Move page in support section"],
    [:operations, SECTION, :trashable_trash] => [TRASH, "Trash support section"],
    [:operations, SECTION, :trashable_restore] => [TRASH, "Restore support section"],
    [:operations, SECTION, :trashable_purge] => [TRASH, "Purge support trash"],
    [:operations, SECTION, :trashable_list_trash_bin] => [TRASH, "List support trash"],
    [:operations, CENTER, :index] => [SUPPORT, "List support centers"],
    [:operations, CENTER, :show] => [SUPPORT, "Show support center"],
    [:operations, CENTER, :create] => [SUPPORT, "Create support center"],
    [:operations, CENTER, :list_access] => [SUPPORT, "List support center access"],
    [:operations, CENTER, :grant_access] => [SUPPORT, "Grant support center access"],
    [:operations, CENTER, :update_access] => [SUPPORT, "Update support center access"],
    [:operations, CENTER, :revoke_access] => [SUPPORT, "Revoke support center access"],
    [:operations, TICKET, :index] => [SUPPORT, "List support tickets"],
    [:operations, TICKET, :show] => [SUPPORT, "Show support ticket"],
    [:operations, TICKET, :update] => [SUPPORT, "Update support ticket"]
  }.freeze

  test "every registered support operation has a group and an action-first title" do
    assert_equal EXPECTED, documented_operations
  end

  test "mcp 0.36.4 reads the per-type title and trash tag suffix" do
    capability_keys.each do |api, type, name|
      action = RecordingStudioApi.capability_action(name, api: api)
      copy = action.openapi_for(type: type, action: action.name)
      group, title = EXPECTED.fetch([api, type, name])

      assert_equal title, mcp_title(action, type)
      assert_equal [group], mcp_groups(api, type, copy)
      refute_includes title, "press kit"
    end
  end

  test "a shared publish press kit title does not replace the support page title" do
    action = RecordingStudioApi.capability_action(:publish, api: :operations)
    original = action.openapi
    action.instance_variable_set(:@openapi, original.merge(title: "Publish press kit"))

    copy = action.openapi_for(type: PAGE)
    other = action.openapi_for(type: "RecordingStudio::Page")

    assert_equal "Publish support page", copy[:title]
    assert_equal "Publish support page", copy[:summary]
    refute_equal "Publish support page", other[:title]
    refute_equal "Publish press kit", copy[:title]
  ensure
    action.instance_variable_set(:@openapi, original) if action && original
  end

  test "openapi document uses the registered titles and groups" do
    document = RecordingStudioApi.openapi_document(api: :operations)
    groups = tag_groups(document)

    assert_equal SUPPORT, groups["Support Page"]
    assert_equal SUPPORT, groups["Support Section"]
    assert_equal SUPPORT, groups["Support Center"]
    assert_equal SUPPORT, groups["Support Ticket"]

    support_operations(document).each do |path, verb, operation|
      title = operation[:title]
      tags = Array(operation[:tags])
      assert title.present?, "#{verb} #{path} is missing a title"
      refute_includes title, "press kit"
      refute_match(/\A(Trash|Ticket) -/, title)
      if tags == [TRASH]
        assert_equal [TRASH], tags
      else
        assert_equal SUPPORT, groups.fetch(tags.first)
      end
    end
  end

  private

  def capability_keys
    EXPECTED.keys.reject { |key| %i[index show create update destroy].include?(key.last) }
  end

  def mcp_title(action, type)
    copy = action.openapi_for(type: type, action: action.name)
    copy[:title].presence || action.openapi[:title]
  end

  def mcp_groups(api, type, copy)
    registration = RecordingStudioApi.recordable_registration_for(type, api: api)
    tags = Array(registration.openapi[:tags]).map(&:to_s)
    suffix = copy[:tag_suffix].to_s.strip
    return tags if suffix.empty?

    tags.map { |tag| "#{tag} #{suffix}" }
  end

  def documented_operations
    %i[public operations].each_with_object({}) do |api, found|
      [PAGE, SECTION, CENTER, TICKET].each do |type|
        registration = RecordingStudioApi.recordable_registration_for(type, api: api)
        next unless registration

        collect_resource_operations(found, api, type, registration)
        collect_capability_operations(found, api, type)
      end
    end
  end

  def collect_resource_operations(found, api, type, registration)
    group = registration.openapi.dig(:tag, :group)
    registration.operations.each do |operation|
      found[[api, type, operation]] = [group, registration.openapi.dig(operation, :title)]
    end
  end

  def collect_capability_operations(found, api, type)
    RecordingStudioApi.capability_actions_for(type, api: api).each do |action|
      copy = action.openapi_for(type: type)
      group = copy.dig(:tag, :group) || SUPPORT
      found[[api, type, action.name.to_sym]] = [group, copy[:title]]
    end
  end

  def support_operations(document)
    document.fetch(:paths).flat_map do |path, verbs|
      next [] unless path.include?("/support_")
      next [] if path.include?("/pages")

      verbs.filter_map do |verb, operation|
        [path, verb, operation] if operation.is_a?(Hash)
      end
    end
  end

  def tag_groups(document)
    Array(document[:"x-tagGroups"]).each_with_object({}) do |group, names|
      Array(group[:tags]).each { |tag| names[tag] = group[:name] }
    end
  end
end
