# frozen_string_literal: true

module RecordingStudioSupport
  module BodyHelper
    # Flatpack List::Item always applies interactive py-3 px-4 after system
    # classes, so TailwindMerge keeps that padding. Article body rows use the
    # same marker structure without Item’s hit-target padding.
    ARTICLE_LIST_ITEM_CLASS = "flex items-start text-[var(--surface-content-color)]"

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

    # TipTap tips stay in blockquote so nested lists still go through Flatpack
    # List. Color matches surrounding prose (surface content), not muted tokens.
    def support_body_blockquote(node)
      content_tag(:div, class: "not-prose") do
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
      content_tag(:li, class: ARTICLE_LIST_ITEM_CLASS, role: "listitem") do
        safe_join([
          content_tag(:span, "", class: "flat-pack-list-item-marker", aria: {hidden: true}),
          content_tag(:div, Body.sanitize(item.inner_html).html_safe, class: "min-w-0 flex-1")
        ])
      end
    end
  end
end
