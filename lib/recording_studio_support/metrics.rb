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
    AUTHORIZE = ->(context) { RecordingStudioSupport::Api::Access.can_view_metrics?(context) }
    OPEN = ->(relation) { relation.where(status: "open") }
    LIVE_PAGES = ->(relation) { relation.merge(RecordingStudioSupport::Admin::Queries.kept_page_recordings) }

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
        api_authorize: AUTHORIZE
      ) { RecordingStudioSupport::Metrics.define_tickets(self) }
    end

    def register_pages!
      RecordingStudioMetrics.register(
        PAGES,
        model: RecordingStudio::Recording,
        blast_radius: :site,
        api_authorize: AUTHORIZE,
        scope: LIVE_PAGES
      ) { RecordingStudioSupport::Metrics.define_pages(self) }
    end

    def define_tickets(dsl)
      dsl.count :open, title: "Open tickets", expose: EXPOSE, scope: OPEN
      dsl.breakdown :by_status, title: "Tickets by status", field: :status, expose: EXPOSE
      dsl.breakdown :by_priority, title: "Tickets by priority", field: :priority, expose: EXPOSE
      dsl.timeseries :opened, title: "Tickets opened", field: :created_at, expose: EXPOSE
    end

    def define_pages(dsl)
      dsl.count :total, title: "Support pages", expose: EXPOSE
    end
  end
end
