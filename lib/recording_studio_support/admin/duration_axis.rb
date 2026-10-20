# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    module DurationAxis
      module_function

      def series(identifier, admin_context, **params)
        rows = Array(Widgets.metric_series(identifier, admin_context, **params))
        values = rows.flat_map { |row| values_for(row) }.compact
        divisor, unit = scale(values)
        rows.map { |row| scale_row(row, divisor, unit) }
      end

      def values_for(row)
        Array(data_for(row)).filter_map { |point| point_value(point) }
      end

      def data_for(row)
        return [] unless row.respond_to?(:[])

        row[:data] || row["data"]
      end

      def point_value(point)
        return point[1] if point.is_a?(Array)

        point[:y] || point["y"] || point[:value] || point["value"] if point.respond_to?(:[])
      end

      def point_x(point)
        return point[0] if point.is_a?(Array)

        point[:x] || point["x"] || point[:date] || point["date"] if point.respond_to?(:[])
      end

      def scale(values)
        max = values.map(&:to_f).max
        return [60, "minutes"] if max.nil? || max < 21_600
        return [3_600, "hours"] if max < 259_200

        [86_400, "days"]
      end

      def scale_row(row, divisor, unit)
        name = row.respond_to?(:[]) ? (row[:name] || row["name"]) : nil
        {
          name: [name, unit].compact.join(" ").strip,
          data: Array(data_for(row)).map { |point| scale_point(point, divisor) }
        }
      end

      def scale_point(point, divisor)
        y = point_value(point)
        { x: point_x(point), y: y.nil? ? nil : axis_number(y.to_f / divisor) }
      end

      def axis_number(value)
        rounded = value.round(1)
        (rounded % 1).zero? ? rounded.to_i : rounded
      end
    end
  end
end
