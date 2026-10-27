# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_support/migrations/migrations_generator"

class MigrationsGeneratorTest < Minitest::Test
  MIGRATION_NAME = "drop_message_group_from_recording_studio_support_tickets.rb"

  def test_copies_the_ticket_migration_by_name
    with_host do |dir|
      copy_migrations(dir)

      copied = Dir.glob(File.join(dir, "db/migrate/*_#{MIGRATION_NAME}"))
      assert_equal 1, copied.size
      assert_includes File.read(copied.first), "DELETE FROM"
    end
  end

  def test_skips_the_ticket_migration_when_the_name_already_exists
    with_host do |dir|
      existing = File.join(dir, "db/migrate/20200101000000_#{MIGRATION_NAME}")
      File.write(existing, "# already installed\n")

      copy_migrations(dir)

      copied = Dir.glob(File.join(dir, "db/migrate/*_#{MIGRATION_NAME}"))
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
