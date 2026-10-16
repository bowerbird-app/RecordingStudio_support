# frozen_string_literal: true

require_relative "api/access"
require_relative "admin/queries"
require "recording_studio_metrics"

module RecordingStudioSupport
  module Metrics
    TICKETS = :support_tickets
    PAGES = :support_pages
    PAGE_VIEWS = :support_page_views
    API = :operations
    EXPOSE = { api: [API] }.freeze
    AUTHORIZE = ->(context) { RecordingStudioSupport::Api::Access.can_view_metrics?(context) }
    OPEN = ->(relation) { relation.where(status: "open") }
    UNASSIGNED_OPEN = ->(relation) { OPEN.call(relation).where(assignee_id: nil) }
    OLDEST_OPEN_AGE = lambda do |relation, _context|
      oldest = relation.minimum(:created_at)
      oldest && (Time.current - oldest).to_i
    end
    QUEUE_GROUPS = %i[priority].freeze
    TICKET_GROUPS = %i[status priority].freeze
    RESOLVED = ->(relation) { relation.where(status: "resolved").where.not(resolved_at: nil) }
    RESOLVE_SECONDS = Arel.sql("EXTRACT(EPOCH FROM (resolved_at - created_at))")
    AVG_RESOLVE_DESCRIPTION = "Mean seconds from opening to resolution for tickets resolved in each " \
                              "period, by resolved_at. Reopened tickets count from their latest resolution."
    PAGE_VIEWS_DESCRIPTION = "Support page views (signed-in and public page shows) by created_at. " \
                             "One row per page show; not de-duplicated by visitor."
    LIVE_PAGES = ->(relation) { relation.merge(RecordingStudioSupport::Admin::Queries.kept_page_recordings) }

    module_function

    def register!
      register_tickets!
      register_pages!
      register_page_views!
    end

    def register_page_views!
      RecordingStudioMetrics.register(
        PAGE_VIEWS,
        model: RecordingStudioSupport::PageView,
        blast_radius: :site,
        api_authorize: AUTHORIZE
      ) { RecordingStudioSupport::Metrics.define_page_views(self) }
    end

    def define_page_views(dsl)
      dsl.timeseries :over_time, title: "Support page views", description: PAGE_VIEWS_DESCRIPTION,
                                 unit: "views", field: :created_at, expose: EXPOSE
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
      dsl.count :open, title: "Open tickets", expose: EXPOSE, scope: OPEN, group_by: QUEUE_GROUPS
      dsl.count :unassigned_open, title: "Unassigned open tickets", expose: EXPOSE, scope: UNASSIGNED_OPEN,
                                  group_by: QUEUE_GROUPS
      dsl.custom :oldest_open_age, title: "Oldest open ticket age", result_type: :scalar, unit: "seconds",
                                   expose: EXPOSE, scope: OPEN, &OLDEST_OPEN_AGE
      dsl.breakdown :by_status, title: "Tickets by status", field: :status, expose: EXPOSE
      dsl.breakdown :by_priority, title: "Tickets by priority", field: :priority, expose: EXPOSE
      dsl.timeseries :opened, title: "Tickets opened", field: :created_at, expose: EXPOSE, group_by: TICKET_GROUPS
      define_avg_time_to_resolve(dsl)
    end

    def define_avg_time_to_resolve(dsl)
      dsl.timeseries :avg_time_to_resolve, title: "Average time to resolve", description: AVG_RESOLVE_DESCRIPTION,
                                           unit: "seconds", field: :resolved_at, measurement: :average,
                                           value_field: RESOLVE_SECONDS, semantics: "records_resolved_during_period",
                                           scope: RESOLVED, group_by: QUEUE_GROUPS, expose: EXPOSE
    end

    def define_pages(dsl)
      dsl.count :total, title: "Support pages", expose: EXPOSE
    end
  end
end
