# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with bin/rails db:setup).

SIGN_IN_IMAGE_PATH = Rails.root.join("db/seed_assets/help-sign-in.png") unless defined?(SIGN_IN_IMAGE_PATH)
SIGN_IN_PNG = File.binread(SIGN_IN_IMAGE_PATH).freeze unless defined?(SIGN_IN_PNG)

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable,
    trashed_at: nil
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

find_or_record_support_page = lambda do |root_recording, title:, body:|
  existing = RecordingStudio::Recording.where(
    root_recording: root_recording,
    parent_recording: root_recording,
    recordable_type: "RecordingStudioSupport::SupportPage",
    trashed_at: nil
  ).find { |recording| recording.recordable.title == title }

  if existing
    if existing.recordable.body != body
      root_recording.revise(existing) do |page|
        page.title = title
        page.body = body
      end
    end
    return existing.reload
  end

  root_recording.record(RecordingStudioSupport::SupportPage) do |page|
    page.title = title
    page.body = body
  end
end

bootstrap_owner_access = lambda do |recording, actor|
  current_role = RecordingStudioAccessible.role_for(actor: actor, recording: recording)
  next if current_role == :admin

  result = RecordingStudioAccessible.bootstrap_owner_access!(
    recording: recording,
    actor: actor
  )
  raise "Failed to bootstrap owner access: #{result.error}" if result.failure?
end

grant_workspace_access = lambda do |recording, actor|
  current_role = RecordingStudioAccessible.role_for(actor: actor, recording: recording)
  next if current_role == :admin

  original = RecordingStudioAccessible.configuration.access_management_authorizer
  begin
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(**) { true }
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: :admin,
      manager_actor: actor
    )
    raise "Failed to grant workspace access: #{result.error}" if result.failure?
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = original
  end
end

# Create the admin user
user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

# Create the workspace recordables
workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")

previous_actor = Current.actor
Current.actor = user

begin
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)
  find_or_record_child.call(page, root_recording, folder_recording)

  admin_root = AdminRoot.find_or_create_by!(name: "Admin")
  admin_root_recording = RecordingStudio.root_recording_for(admin_root)
  bootstrap_owner_access.call(admin_root_recording, user)

  [root_recording, accessible_root_recording, private_root_recording].each do |recording|
    grant_workspace_access.call(recording, user)
  end

  sign_in_page = find_or_record_support_page.call(
    root_recording,
    title: "How do I sign in?",
    body: "Use the email and password you were given. Still stuck? Ask a teammate who already has access."
  )
  password_page = find_or_record_support_page.call(
    root_recording,
    title: "How do I change my password?",
    body: "Open your account settings and pick a new password. Then use the new one next time."
  )

  if sign_in_page.images.none?
    attachment = sign_in_page.import_attachment(
      io: StringIO.new(SIGN_IN_PNG),
      filename: "sign-in.png",
      content_type: "image/png",
      actor: user
    )
    raise "Failed to attach sign-in.png" if attachment.blank?
  end

  [sign_in_page, password_page].each do |support_recording|
    next if RecordingStudioSupport::PageView.exists?(recording_id: support_recording.id)

    3.times do
      RecordingStudioSupport::PageView.record!(recording: support_recording, actor: user)
    end
  end
ensure
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
puts "Seeded: Support pages 'How do I sign in?' and 'How do I change my password?'"
puts "Seeded: Admin root with owner access for admin@admin.com"
