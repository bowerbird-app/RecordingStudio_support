# frozen_string_literal: true

module RecordingStudioSupport
  module BodyHelper
    MUTED_BODY_CLASS = "not-prose text-[var(--surface-muted-content-color)]"

    def support_page_body_html(body)
      fragment = Body.loofah_fragment(Body.sanitize(body))
      safe_join(fragment.children.filter_map { |node| support_body_node(node) })
    end

    private

    def support_body_node(node)
      return if node.text? && node.content.blank?
      return ERB::Util.html_escape(node.content) if node.text?

      case node.name
      when "ol"
        support_body_list(node, ordered: true)
      when "ul"
        support_body_list(node, ordered: false)
      when "blockquote"
        content_tag(:div, class: MUTED_BODY_CLASS) do
          safe_join(node.children.filter_map { |child| support_body_node(child) })
        end
      else
        node.to_html.html_safe
      end
    end

    def support_body_list(node, ordered:)
      render FlatPack::List::Component.new(
        ordered: ordered,
        spacing: :dense,
        class: "not-prose"
      ) do
        safe_join(
          node.xpath("./li").map do |item|
            render(FlatPack::List::Item.new) do
              Body.sanitize(item.inner_html).html_safe
            end
          end
        )
      end
    end
  end
end
