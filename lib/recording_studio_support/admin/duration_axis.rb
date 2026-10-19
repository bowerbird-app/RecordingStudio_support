# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    module DurationAxis
      module_function

      def series(identifier, admin_context)
        rows = Array(Widgets.metric_series(identifier, admin_context))
        values = rows.flat_map { |row| ChartSeries.data_for(row).filter_map { |point| ChartSeries.point_value(point) } }
        divisor, unit = scale(values)
        rows.map { |row| scale_row(row, divisor, unit) }
      end

      def scale(values)
        max = values.map(&:to_f).max
        return [60, "minutes"] if max.nil? || max < 21_600
        return [3_600, "hours"] if max < 259_200

        [86_400, "days"]
      end

      def scale_row(row, divisor, unit)
        {
          name: [ChartSeries.name_for(row), unit].compact.join(" ").strip,
          data: Array(ChartSeries.data_for(row)).map { |point| scale_point(point, divisor) }
        }
      end

      def scale_point(point, divisor)
        y = ChartSeries.point_value(point)
        ChartSeries.xy(point, value: y.nil? ? nil : axis_number(y.to_f / divisor))
      end

      def axis_number(value)
        rounded = value.round(1)
        (rounded % 1).zero? ? rounded.to_i : rounded
      end
    end
  end
end
