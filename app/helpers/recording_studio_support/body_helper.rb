# frozen_string_literal: true

module RecordingStudioSupport
  module BodyHelper
    # Flatpack ContentEditor’s content region is the kit’s long-form TipTap
    # display surface (heading scale, paragraph rhythm, image rules). Public
    # and staff article bodies reuse that class; they do not mount the editor.
    ARTICLE_BODY_CLASS = "flat-pack-content-editor-content max-w-none"
    ARTICLE_IMAGE_STYLE = "width: 100%; height: auto; display: block; border-radius: var(--radius-md, 1rem);"
    ARTICLE_FIGURE_STYLE = "margin: 1.5rem 0;"

    # Flatpack List::Item always applies interactive py-3 px-4 after system
    # classes, so TailwindMerge keeps that padding. Article body rows use the
    # same marker structure without Item’s hit-target padding.
    ARTICLE_LIST_ITEM_CLASS = "flex items-start text-[var(--surface-content-color)]"
    BODY_ELEMENT_HANDLERS = {
      "blockquote" => :support_body_blockquote,
      "img" => :support_body_image,
      "p" => :support_body_paragraph
    }.freeze

    def support_page_body_html(body)
      fragment = Body.loofah_fragment(Body.sanitize(body))
      safe_join(fragment.children.filter_map { |node| support_body_node(node) })
    end

    def support_page_body_class(extra = nil)
      [ARTICLE_BODY_CLASS, extra].compact.join(" ")
    end

    private

    def support_body_node(node)
      return support_body_text(node) if node.text?

      support_body_element(node)
    end

    def support_body_text(node)
      return if node.content.blank?

      ERB::Util.html_escape(node.content)
    end

    def support_body_element(node)
      name = node.name
      return support_body_list(node, ordered: node.name == "ol") if %w[ol ul].include?(name)

      handler = BODY_ELEMENT_HANDLERS[name]
      handler ? send(handler, node) : node.to_html.html_safe
    end

    def support_body_paragraph(node)
      children = node.children.reject { |child| child.text? && child.content.blank? }
      return support_body_image(children.first) if children.one? && children.first.name == "img"

      node.to_html.html_safe
    end

    def support_body_image(node)
      content_tag(:figure, style: ARTICLE_FIGURE_STYLE) do
        tag.img(src: node["src"], alt: node["alt"], style: ARTICLE_IMAGE_STYLE)
      end
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
                    content_tag(:span, "", class: "flat-pack-list-item-marker", aria: { hidden: true }),
                    content_tag(:div, Body.sanitize(item.inner_html).html_safe, class: "min-w-0 flex-1")
                  ])
      end
    end
  end
end
