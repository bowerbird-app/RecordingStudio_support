# frozen_string_literal: true

require "test_helper"

class SupportTicketWritesTest < Minitest::Test
  ALLOWED = %w[
    lib/recording_studio_support/tickets/open.rb
    lib/recording_studio_support/tickets/update.rb
  ].freeze
  CLASS_WRITE = /
    SupportTicket\s*\.\s*
    (?:create!?|save!?|update!?|update_all|insert!?|insert_all!?|find_or_create_by!?)
    \b
  /x
  INSTANCE_WRITE = /
    (?:@ticket|ticket|support_ticket)\s*\.\s*(?:update!?|save!?)\b
  /x
  NEW_THEN_SAVE = /SupportTicket\.new\b.{0,500}\.save!?\b/m

  def test_ticket_rows_are_written_only_inside_the_ticket_service
    offenders = []
    scanned_files.each do |path|
      relative = path.delete_prefix("#{repo_root}/")
      next if ALLOWED.include?(relative)

      scan_file(path, relative, offenders)
    end

    assert_empty offenders
  end

  private

  def scanned_files
    Dir.glob(File.join(repo_root, "{app,lib,test/dummy}/**/*.rb"))
  end

  def repo_root
    File.expand_path("..", __dir__)
  end

  def scan_file(path, relative, offenders)
    code = strip_comments(File.read(path))
    code.lines.each_with_index do |line, index|
      next unless line.match?(CLASS_WRITE) || line.match?(INSTANCE_WRITE)

      offenders << "#{relative}:#{index + 1}: #{line.strip}"
    end
    return unless code.match?(NEW_THEN_SAVE)

    offenders << "#{relative}: SupportTicket.new then save"
  end

  def strip_comments(source)
    source.gsub(/#[^\n]*/, "")
  end
end
