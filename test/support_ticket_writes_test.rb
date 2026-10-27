# frozen_string_literal: true

require "test_helper"

class SupportTicketWritesTest < Minitest::Test
  ALLOWED = %w[
    lib/recording_studio_support/tickets/open.rb
    lib/recording_studio_support/tickets/update.rb
  ].freeze
  WRITE_METHODS = %w[
    create create! save save! update update! update_all
    update_column update_columns insert insert! insert_all insert_all!
    upsert upsert! upsert_all upsert_all! find_or_create_by find_or_create_by!
    delete delete! delete_all destroy destroy! destroy_all
  ].freeze
  WRITE_PATTERN = WRITE_METHODS.map { |name| Regexp.escape(name) }.join("|").freeze
  CLASS_WRITE = /
    SupportTicket\s*\.\s*
    (?:#{WRITE_PATTERN})
    \b
  /x
  INSTANCE_WRITE = /
    @?\w*ticket\w*\s*\.\s*
    (?:#{WRITE_PATTERN})
    \b
  /x
  NEW_THEN_SAVE = /SupportTicket\.new\b.{0,500}\.save!?\b/m
  STRING_OR_COMMENT = /
    "(?:\\.|\#\{[^{}]*\}|[^"\\])*"
    | '(?:\\.|[^'\\])*'
    | \#[^\n]*
  /x

  def test_ticket_rows_are_written_only_inside_the_ticket_service
    assert_empty offenders_in(repo_sources)
  end

  def test_the_guard_flags_direct_writes_on_other_receivers
    snippet = <<~RUBY
      old_ticket.delete
      tickets.destroy_all
      SupportTicket.update_columns(status: "open")
      SupportTicket.upsert({})
      SupportTicket.update_all(status: "open")
      note = "\#{ticket.id}"; ticket.update_column(:status, "open")
    RUBY

    assert_equal 6, offenders_in([["sample.rb", snippet]]).size
  end

  def test_comments_and_interpolation_are_not_writes
    snippet = <<~RUBY
      # old_ticket.delete
      # SupportTicket.delete_all
      note = "\#{ticket.id}"
      Tickets.update!(ticket, actor: staff)
    RUBY

    assert_empty offenders_in([["sample.rb", snippet]])
  end

  private

  def offenders_in(sources)
    sources.flat_map { |relative, code| scan_source(code, relative) }
  end

  def repo_sources
    Dir.glob(File.join(repo_root, "{app,lib,test/dummy}/**/*.rb")).filter_map do |path|
      relative = path.delete_prefix("#{repo_root}/")
      next if ALLOWED.include?(relative)

      [relative, File.read(path)]
    end
  end

  def repo_root
    File.expand_path("..", __dir__)
  end

  def scan_source(code, relative)
    stripped = strip_comments(code)
    offenders = []
    stripped.lines.each_with_index do |line, index|
      next unless line.match?(CLASS_WRITE) || line.match?(INSTANCE_WRITE)

      offenders << "#{relative}:#{index + 1}: #{line.strip}"
    end
    offenders << "#{relative}: SupportTicket.new then save" if stripped.match?(NEW_THEN_SAVE)
    offenders
  end

  def strip_comments(source)
    source.gsub(STRING_OR_COMMENT) { |token| token.start_with?("#") ? "" : token }
  end
end
