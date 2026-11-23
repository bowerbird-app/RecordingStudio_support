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
    [:public, TICKET, :index] => ["Support Ticket", "List support tickets"],
    [:public, TICKET, :show] => ["Support Ticket", "Show support ticket"],
    [:public, TICKET, :create] => ["Support Ticket", "Open support ticket"],
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

  PUBLIC_CAPABILITY_ACTIONS = %w[
    move publish unpublish update_publishable
    trashable_trash trashable_restore trashable_purge trashable_list_trash_bin
  ].freeze

  test "public pages and search share one tag and tickets have their own group" do
    page = RecordingStudioApi.recordable_registration_for(PAGE, api: :public)
    ticket = RecordingStudioApi.recordable_registration_for(TICKET, api: :public)
    endpoint = RecordingStudioApi.registered_endpoint(:search_support_pages, api: :public)
    messages = RecordingStudioApi.registered_endpoint(:list_support_ticket_messages, api: :public)
    page_tag = ["Support Page"]
    ticket_tag = ["Support Ticket"]
    messages_tag = ["Support Messages"]

    assert_equal %i[index show], page.operations
    assert_equal %i[create index show], ticket.operations
    assert_empty RecordingStudioApi.capability_actions_for(PAGE, api: :public)
    assert_empty RecordingStudioApi.capability_actions_for(TICKET, api: :public)
    assert_equal page_tag, page.openapi.fetch(:tags)
    assert_equal page_tag, endpoint.openapi_tags
    assert_equal page_tag, mcp_type_tags(:public, PAGE)
    assert_equal ticket_tag, ticket.openapi.fetch(:tags)
    assert_equal "Support Ticket", ticket.openapi.dig(:tag, :group)
    assert_equal ticket_tag, mcp_type_tags(:public, TICKET)
    assert_equal messages_tag, messages.openapi_tags
    assert_equal "Support Messages", messages.openapi.dig(:tag, :group)
    assert_equal ["Support"], mcp_type_tags(:operations, PAGE)
    assert_equal ["Support"], mcp_type_tags(:operations, TICKET)

    document = RecordingStudioApi.openapi_document(api: :public)
    groups = tag_groups(document)
    page_operations = public_support_operations(document)
    page_titles = page_operations.map { |_path, _verb, operation| operation[:title] }
    page_tags = page_operations.flat_map { |_path, _verb, operation| Array(operation[:tags]) }.uniq
    ticket_operations = public_ticket_operations(document)
    ticket_titles = ticket_operations.map { |_path, _verb, operation| operation[:title] }
    ticket_tags = ticket_operations.flat_map { |_path, _verb, operation| Array(operation[:tags]) }.uniq
    message_operations = public_message_operations(document)
    message_tags = message_operations.flat_map { |_path, _verb, operation| Array(operation[:tags]) }.uniq

    assert_equal page_tag, page_tags
    assert_includes page_titles, "List support pages"
    assert_includes page_titles, "Show support page"
    assert_includes page_titles, "Search support pages"
    refute_includes page_titles, "Create support page"
    assert_equal ticket_tag, ticket_tags
    assert_includes ticket_titles, "List support tickets"
    assert_includes ticket_titles, "Show support ticket"
    assert_includes ticket_titles, "Open support ticket"
    assert_equal messages_tag, message_tags
    assert_equal SUPPORT, groups.fetch("Support Page")
    assert_equal "Support Ticket", groups.fetch("Support Ticket")
    refute_includes groups.keys, "Support"
    Array(document[:"x-tagGroups"]).each do |group|
      assert Array(group[:tags]).any?, group.inspect
    end
  end

  test "public search is documented for OpenAPI and MCP and public pages have no capability actions" do
    assert_empty RecordingStudioApi.capability_actions_for(PAGE, api: :public)

    endpoint = RecordingStudioApi.registered_endpoint(:search_support_pages, api: :public)
    assert_equal "Search support pages", endpoint.openapi[:title]
    assert_equal "Search support pages", endpoint.openapi[:summary]
    assert_equal ["Support Page"], endpoint.openapi_tags
    assert_match(/\A[A-Za-z][A-Za-z0-9_.-]*\z/, endpoint.name)
    refute_includes %w[list show create update delete capability_action describe], endpoint.name
    assert_nil RecordingStudioApi.registered_endpoint(:search_support_pages, api: :operations)

    document = RecordingStudioApi.openapi_document(api: :public)
    _path, operation = public_search_operation(document)
    assert_equal "Search support pages", operation[:title]
    assert_equal "Search support pages", operation[:summary]
    assert_equal ["Support Page"], operation[:tags]
    assert_equal SUPPORT, tag_groups(document).fetch("Support Page")
    assert operation[:parameters].any? { |parameter|
      (parameter[:name] || parameter["name"]) == "q" && (parameter[:in] || parameter["in"]) == "query"
    }

    paths = document.fetch(:paths).keys
    PUBLIC_CAPABILITY_ACTIONS.each do |name|
      refute paths.any? { |path| path.include?("/support_") && path.end_with?("/#{name}") }, name
    end
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
      elsif tags == ["Support Messages"]
        assert_equal ["Support Messages"], tags
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

  def mcp_type_tags(api, type)
    registration = RecordingStudioApi.recordable_registration_for(type, api: api)
    Array(registration.openapi[:tags]).map(&:to_s)
  end

  def mcp_groups(api, type, copy)
    suffix = copy[:tag_suffix].to_s.strip
    tags = mcp_type_tags(api, type)
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

  def public_support_operations(document)
    document.fetch(:paths).flat_map do |path, verbs|
      next [] unless path.include?("/support_pages") || path.end_with?("/support_page_search")

      verbs.filter_map do |verb, operation|
        [path, verb, operation] if operation.is_a?(Hash)
      end
    end
  end

  def public_ticket_operations(document)
    document.fetch(:paths).flat_map do |path, verbs|
      next [] unless path.include?("/support_tickets")
      next [] if message_path?(path)

      verbs.filter_map do |verb, operation|
        [path, verb, operation] if operation.is_a?(Hash)
      end
    end
  end

  def public_message_operations(document)
    document.fetch(:paths).flat_map do |path, verbs|
      next [] unless message_path?(path) || path.end_with?("/support_ticket_unread_count")

      verbs.filter_map do |verb, operation|
        [path, verb, operation] if operation.is_a?(Hash)
      end
    end
  end

  def message_path?(path)
    path.include?("/support_ticket_messages") ||
      path.include?("/support_ticket_reply") ||
      path.include?("/support_ticket_mark_read") ||
      path.end_with?("/support_ticket_unread_count")
  end

  def public_search_operation(document)
    document.fetch(:paths).each do |path, verbs|
      next unless path.end_with?("/support_page_search")

      return [path, verbs[:get] || verbs["get"]]
    end

    flunk "public OpenAPI is missing support_page_search"
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
