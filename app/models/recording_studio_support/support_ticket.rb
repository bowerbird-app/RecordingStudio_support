# frozen_string_literal: true

module RecordingStudioSupport
  class SupportTicket < ApplicationRecord
    self.table_name = "recording_studio_support_tickets"

    recording_studio_recordable label: "Support ticket",
                                root: false,
                                allowed_parent_types: ["RecordingStudioMessages::MessageGroup"]

    STATUSES = %w[
      open
      waiting_on_customer
      waiting_on_support
      resolved
    ].freeze

    PRIORITIES = %w[
      low
      normal
      high
    ].freeze

    belongs_to :assignee, polymorphic: true, optional: true

    enum :status, STATUSES.to_h { |status| [status.to_sym, status] }, validate: true
    enum :priority, PRIORITIES.to_h { |priority| [priority.to_sym, priority] },
         validate: true, default: :normal

    validates :subject, presence: true

    before_validation :sync_resolved_at

    private

    def sync_resolved_at
      if status.to_s == "resolved"
        self.resolved_at ||= Time.current
      else
        self.resolved_at = nil
      end
    end
  end
end
