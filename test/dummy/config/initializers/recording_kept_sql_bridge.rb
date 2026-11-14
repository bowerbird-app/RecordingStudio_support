# frozen_string_literal: true

# Recording Studio API 0.23.1 still calls the helper Trashable 0.16.0 removed.
# Support does not define it. This dummy bridge keeps those API requests on
# RecordingStudio.kept_sql until that gem moves over.
module RecordingKeptSqlBridge
  def recording_studio_trashable_kept_sql(table = table_name)
    RecordingStudio.kept_sql(table)
  end
end

Rails.application.config.after_initialize do
  RecordingStudio::Recording.extend(RecordingKeptSqlBridge)
end
