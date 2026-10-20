# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    module ChartFilters
      GROUPS = %i[day week month].freeze

      module_function

      def metric_params(context)
        range = context.filter_value(:date_range) if context.respond_to?(:filter_value)
        params = { interval: interval_from(context) }
        start_at = bound(range, :start_date, :beginning_of_day)
        end_at = bound(range, :end_date, :end_of_day)
        params[:start_at] = start_at if start_at
        params[:end_at] = end_at if end_at
        params
      end

      def interval_from(context)
        value = context.filter_value(:group_by) if context.respond_to?(:filter_value)
        key = value.to_s.downcase.to_sym
        GROUPS.include?(key) ? key : :day
      end

      def bound(range, edge, rounding)
        value = range.public_send(edge) if range.respond_to?(edge)
        value.public_send(rounding) if value.respond_to?(rounding)
      end
    end
  end
end
