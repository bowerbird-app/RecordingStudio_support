# frozen_string_literal: true

module RecordingStudioSupport
  module Admin
    module XySeries
      module_function

      def from(series)
        Array(series).map { |row| row_for(row) }
      end

      def row_for(row)
        name = row.respond_to?(:[]) ? (row[:name] || row["name"]) : nil
        { name: name, data: Array(data_for(row)).map { |point| point_for(point) } }
      end

      def data_for(row)
        return [] unless row.respond_to?(:[])

        inner = row[:data] || row["data"]
        return inner unless inner.nil?

        [row]
      end

      def point_for(point)
        { x: x_for(point), y: y_for(point) }
      end

      def x_for(point)
        label_for(DurationAxis.point_x(point))
      end

      def y_for(point)
        DurationAxis.point_value(point)
      end

      def label_for(raw)
        return if raw.nil?
        return raw.strftime("%Y-%m-%d") if raw.respond_to?(:strftime)

        raw.to_s
      end
    end
  end
end
