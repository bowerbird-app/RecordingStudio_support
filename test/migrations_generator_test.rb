# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_support/migrations/migrations_generator"

class MigrationsGeneratorTest < Minitest::Test
  TICKET_MIGRATION = "create_recording_studio_support_tickets.rb"
  CENTER_MIGRATION = "create_recording_studio_support_centers.rb"

  def test_copies_the_ticket_and_center_migrations_by_name
    with_host do |dir|
      copy_migrations(dir)

      tickets = Dir.glob(File.join(dir, "db/migrate/*_#{TICKET_MIGRATION}"))
      centers = Dir.glob(File.join(dir, "db/migrate/*_#{CENTER_MIGRATION}"))
      assert_equal 1, tickets.size
      assert_equal 1, centers.size
      refute_includes File.read(tickets.first), "message_group_id"
      assert_includes File.read(centers.first), "create_table :recording_studio_support_centers"
      assert_empty Dir.glob(File.join(dir, "db/migrate/*drop_message_group*"))
    end
  end

  def test_skips_the_ticket_migration_when_the_name_already_exists
    with_host do |dir|
      existing = File.join(dir, "db/migrate/20200101000000_#{TICKET_MIGRATION}")
      File.write(existing, "# already installed\n")

      copy_migrations(dir)

      copied = Dir.glob(File.join(dir, "db/migrate/*_#{TICKET_MIGRATION}"))
      assert_equal [existing], copied
    end
  end

  private

  def with_host
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "db/migrate"))
      yield dir
    end
  end

  def copy_migrations(dir)
    generator = RecordingStudioSupport::Generators::MigrationsGenerator.new(
      [],
      {},
      destination_root: dir
    )
    generator.stub(:sleep, nil) { generator.copy_migrations }
  end
end
