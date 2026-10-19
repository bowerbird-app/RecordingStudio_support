# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    # Admin / Flatpack line charts plot category points `{ x:, y: }`.
    # Metrics `chart_series` returns `[date, value]` tuples, which ApexCharts
    # treats as a datetime XY series and draws as an empty chart.
    module ChartSeries
      module_function

      def from_metrics(identifier, admin_context)
        rows(Widgets.metric_series(identifier, admin_context))
      end

      def rows(series)
        Array(series).map { |row| { name: name_for(row), data: points_for(row) } }
      end

      def points_for(row)
        Array(data_for(row)).map { |point| xy(point) }
      end

      def xy(point, value: :keep)
        plotted = value == :keep ? point_value(point) : value
        { x: category_x(point_x(point)), y: numeric_y(plotted) }
      end

      def data_for(row)
        return [] unless row.respond_to?(:[])

        row[:data] || row["data"]
      end

      def name_for(row)
        row.respond_to?(:[]) ? (row[:name] || row["name"]) : nil
      end

      def point_value(point)
        return point[1] if point.is_a?(Array)

        point[:y] || point["y"] || point[:value] || point["value"] if point.respond_to?(:[])
      end

      def point_x(point)
        return point[0] if point.is_a?(Array)

        point[:x] || point["x"] || point[:date] || point["date"] if point.respond_to?(:[])
      end

      def category_x(value)
        time = parse_time(value)
        return time.strftime("%b %-d") if time

        value.to_s
      end

      def numeric_y(value)
        return if value.nil?

        number = value.to_f
        (number % 1).zero? ? number.to_i : number
      end

      def parse_time(value)
        return value if value.respond_to?(:strftime) && !value.is_a?(String)
        return if value.blank?

        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
