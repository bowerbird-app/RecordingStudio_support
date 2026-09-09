# frozen_string_literal: true

module RecordingStudioSupport
  module BodyHelper
    # Secondary tip blocks: muted token + stock opacity so Flatpack List item
    # content-color still reads quieter than the main steps.
    MUTED_BODY_CLASS = "not-prose text-[var(--surface-muted-content-color)] opacity-75"

    def support_page_body_html(body)
      fragment = Body.loofah_fragment(Body.sanitize(body))
      safe_join(fragment.children.filter_map { |node| support_body_node(node) })
    end

    private

    def support_body_node(node)
      return if node.text? && node.content.blank?
      return ERB::Util.html_escape(node.content) if node.text?
      return support_body_list(node, ordered: node.name == "ol") if %w[ol ul].include?(node.name)
      return support_body_blockquote(node) if node.name == "blockquote"

      node.to_html.html_safe
    end

    def support_body_blockquote(node)
      content_tag(:div, class: MUTED_BODY_CLASS) do
        safe_join(node.children.filter_map { |child| support_body_node(child) })
      end
    end

    def support_body_list(node, ordered:)
      items = node.xpath("./li").map { |item| support_body_list_item(item) }
      render FlatPack::List::Component.new(ordered: ordered, spacing: :dense, class: "not-prose") do
        safe_join(items)
      end
    end

    def support_body_list_item(item)
      render(FlatPack::List::Item.new) { Body.sanitize(item.inner_html).html_safe }
    end
  end
end
