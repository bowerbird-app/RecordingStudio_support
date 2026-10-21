# frozen_string_literal: true

namespace :recording_studio_support do
  desc "Copy recording_studio_support_page_views into Views raw logs (idempotent)"
  task backfill_page_views: :environment do
    result = RecordingStudioSupport::PageViewBackfill.call
    puts "copied=#{result.copied} skipped=#{result.skipped}"
  end
end
