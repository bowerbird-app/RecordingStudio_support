# frozen_string_literal: true

module RecordingStudioSupport
  module ListHelper
    def support_list_chevron
      render FlatPack::Shared::IconComponent.new(name: "chevron-right", size: :md)
    end

    def support_page_count_label(page_count)
      page_count.to_s
    end

    def support_article_count_label(page_count)
      count = page_count.to_i
      "#{count} #{'article'.pluralize(count)}"
    end

    def support_section_icon_name(recording_or_section)
      section = if recording_or_section.respond_to?(:recordable)
                  recording_or_section.recordable
                else
                  recording_or_section
                end
      section&.icon.to_s.presence
    end

    def support_section_icon(recording_or_section, size: :lg)
      name = support_section_icon_name(recording_or_section)
      return if name.blank?

      render FlatPack::Shared::IconComponent.new(
        name: name,
        size: size,
        class: "text-[var(--surface-content-color)]"
      )
    end

    def support_page_count_badge(page_count)
      render FlatPack::Badge::Component.new(
        text: support_page_count_label(page_count),
        style: :default,
        size: :xs
      )
    end

    def support_published_badge
      render FlatPack::Badge::Component.new(text: "Published", style: :success, size: :xs)
    end

    def support_page_status_badge(recording)
      if recording.respond_to?(:current_publishable) && recording.current_publishable
        render RecordingStudioPublishable::StatusBadge::Component.new(
          publishable: recording.current_publishable
        )
      else
        render FlatPack::Badge::Component.new(text: "Draft", style: :info, size: :xs)
      end
    end

    def support_section_options(section_recordings)
      Array(section_recordings).filter_map do |recording|
        title = support_recording_title(recording)
        next if title.blank?

        [title, recording.id]
      end
    end
  end
end
