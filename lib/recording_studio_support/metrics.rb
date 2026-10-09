# frozen_string_literal: true

require_relative "api/access"
require_relative "admin/queries"
require "recording_studio_metrics"

module RecordingStudioSupport
  module Metrics
    TICKETS = :support_tickets
    PAGES = :support_pages
    API = :operations
    EXPOSE = { api: [API] }.freeze

    module_function

    def register!
      register_tickets!
      register_pages!
    end

    def register_tickets!
      RecordingStudioMetrics.register(
        TICKETS,
        model: RecordingStudioSupport::SupportTicket,
        blast_radius: :site,
        api_authorize: ->(context) { RecordingStudioSupport::Api::Access.can_view_as_staff?(context) }
      ) do
        count :open,
              title: "Open tickets",
              expose: RecordingStudioSupport::Metrics::EXPOSE,
              scope: ->(relation) { relation.where(status: "open") }
        breakdown :by_status,
                  title: "Tickets by status",
                  field: :status,
                  expose: RecordingStudioSupport::Metrics::EXPOSE
        breakdown :by_priority,
                  title: "Tickets by priority",
                  field: :priority,
                  expose: RecordingStudioSupport::Metrics::EXPOSE
        timeseries :opened,
                   title: "Tickets opened",
                   field: :created_at,
                   expose: RecordingStudioSupport::Metrics::EXPOSE
      end
    end

    def register_pages!
      RecordingStudioMetrics.register(
        PAGES,
        model: RecordingStudio::Recording,
        blast_radius: :site,
        api_authorize: ->(context) { RecordingStudioSupport::Api::Access.can_view_as_staff?(context) },
        scope: ->(relation) { relation.merge(RecordingStudioSupport::Admin::Queries.kept_page_recordings) }
      ) do
        count :total,
              title: "Support pages",
              expose: RecordingStudioSupport::Metrics::EXPOSE
      end
    end
  end
end
