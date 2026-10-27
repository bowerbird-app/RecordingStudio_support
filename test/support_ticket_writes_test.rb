# frozen_string_literal: true

require "test_helper"

class SupportTicketWritesTest < Minitest::Test
  WRITE_PATTERN = /SupportTicket\.(create!|save!|update!?)/

  def test_ticket_rows_are_written_only_inside_the_ticket_service
    offenders = []

    %w[app lib].each do |directory|
      Dir.glob(File.expand_path("../#{directory}/**/*.rb", __dir__)).each do |path|
        next if path.include?("/tickets/")

        File.readlines(path).each_with_index do |line, index|
          next unless line.match?(WRITE_PATTERN)

          offenders << "#{path}:#{index + 1}: #{line.strip}"
        end
      end
    end

    assert_empty offenders
  end
end
