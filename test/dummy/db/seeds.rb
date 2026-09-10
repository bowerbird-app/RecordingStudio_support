# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with bin/rails db:setup).

SIGN_IN_BODY = <<~HTML.freeze unless defined?(SIGN_IN_BODY)
  <h2>Open the sign-in page</h2>
  <p>Use the address your workspace gave you. You will see the sign-in form.</p>
  <p><img src="/how-to-sign-in.jpg" alt="Sign-in form"></p>
  <h2>Enter your details</h2>
  <p>Use the email and password you were given.</p>
  <ul>
    <li>Your email</li>
    <li>Your password</li>
  </ul>
  <p>Then choose Sign in. Still stuck? Ask a teammate who already has access.</p>
HTML

PAYMENT_BODY = <<~HTML.freeze unless defined?(PAYMENT_BODY)
  <h2>Open billing</h2>
  <p>From your workspace, open Billing. You will see the card on file and a place to change it.</p>
  <p><img src="/how-to-update-payment.jpg" alt="Billing settings with card on file and payment fields"></p>
  <h2>Add or replace a card</h2>
  <p>Choose Update payment details, then enter the new card.</p>
  <ol>
    <li>Name on the card</li>
    <li>Card number</li>
    <li>Expiry and security code</li>
  </ol>
  <h2>Save and confirm</h2>
  <p>Choose Save. The next invoice uses the card you just saved.</p>
  <blockquote>
    <ul>
      <li>You can keep more than one card on file in some plans</li>
      <li>Failed charges still show under Invoices until they clear</li>
    </ul>
    <p>Need a receipt instead? Open Invoices and download the PDF.</p>
  </blockquote>
HTML

INVOICE_BODY = <<~HTML.freeze unless defined?(INVOICE_BODY)
  <h2>Find Invoices</h2>
  <p>Open Billing, then Invoices. Paid invoices sit at the top of the list.</p>
  <h2>Download a PDF</h2>
  <p>Pick any paid invoice and choose Download. The PDF opens in a new tab.</p>
  <ul>
    <li>Date and amount</li>
    <li>Plan name</li>
    <li>Last four digits of the card charged</li>
  </ul>
HTML

API_KEY_BODY = <<~HTML.freeze unless defined?(API_KEY_BODY)
  <h2>Open developer settings</h2>
  <p>In your workspace, open Developer settings. The API key is on that page.</p>
  <h2>Copy the key</h2>
  <p>Choose Copy. Treat the key like a password — do not paste it into chat or a public repo.</p>
  <ol>
    <li>Copy the key</li>
    <li>Store it in your secret store</li>
    <li>Rotate it if it leaks</li>
  </ol>
HTML

PASSWORD_BODY = <<~HTML.freeze unless defined?(PASSWORD_BODY)
  <h2>Open account settings</h2>
  <p>Open your account settings and pick a new password.</p>
  <h2>Use it next time</h2>
  <p>Come back with the new password the next time you sign in.</p>
HTML

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

find_or_record_support_section = lambda do |root_recording, title:, icon: nil|
  existing = RecordingStudio::Recording.where(
    root_recording: root_recording,
    parent_recording: root_recording,
    recordable_type: "RecordingStudioSupport::SupportSection",
    trashed_at: nil
  ).find { |recording| recording.recordable.title == title }

  if existing
    section = existing.recordable
    if section.icon.to_s != icon.to_s
      root_recording.revise(existing) do |revised|
        revised.icon = icon
      end
      existing.reload
    end
    return existing
  end

  root_recording.record(RecordingStudioSupport::SupportSection) do |section|
    section.title = title
    section.icon = icon
  end
end

find_or_record_support_page = lambda do |root_recording, parent_recording, title:, body:, description: nil|
  existing = RecordingStudio::Recording.where(
    root_recording: root_recording,
    recordable_type: "RecordingStudioSupport::SupportPage",
    trashed_at: nil
  ).find { |recording| recording.recordable.title == title }

  if existing
    if existing.parent_recording_id != parent_recording.id
      existing.move_to!(new_parent: parent_recording, actor: Current.actor)
      existing.reload
    end
    page = existing.recordable
    if page.body != body || page.description.to_s != description.to_s
      root_recording.revise(existing) do |revised|
        revised.title = title
        revised.description = description
        revised.body = body
      end
    end
    return existing.reload
  end

  root_recording.record(RecordingStudioSupport::SupportPage, parent_recording: parent_recording) do |page|
    page.title = title
    page.description = description
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

# Create the admin user through Users (Devise actor + Profile under People).
user = User.find_by(email: "admin@admin.com")
if user.nil?
  user = RecordingStudioUser.create_user!(
    email: "admin@admin.com",
    password: "Password",
    first_name: "Avery",
    last_name: "Admin",
    time_zone: "UTC"
  )
elsif RecordingStudioUser.profile_for(user).nil?
  RecordingStudioUser.record_profile!(
    user,
    first_name: "Avery",
    last_name: "Admin",
    time_zone: "UTC",
    actor: user
  )
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

  billing_section = find_or_record_support_section.call(root_recording, title: "Billing", icon: "credit-card")
  developers_section = find_or_record_support_section.call(root_recording, title: "Developers", icon: "code-bracket")
  getting_started_section = find_or_record_support_section.call(root_recording, title: "Getting started", icon: "rocket-launch")

  sign_in_page = find_or_record_support_page.call(
    root_recording,
    getting_started_section,
    title: "How do I sign in?",
    description: "Use the email and password you were given.",
    body: SIGN_IN_BODY
  )
  password_page = find_or_record_support_page.call(
    root_recording,
    getting_started_section,
    title: "How do I change my password?",
    description: "Pick a new password in account settings.",
    body: PASSWORD_BODY
  )
  billing_page = find_or_record_support_page.call(
    root_recording,
    billing_section,
    title: "How do I update payment details?",
    description: "Open billing and save the card you want us to use.",
    body: PAYMENT_BODY
  )
  invoice_page = find_or_record_support_page.call(
    root_recording,
    billing_section,
    title: "Where is my invoice?",
    description: "Open Billing, then Invoices. Download any paid invoice as a PDF.",
    body: INVOICE_BODY
  )
  developers_page = find_or_record_support_page.call(
    root_recording,
    developers_section,
    title: "Where do I find my API key?",
    description: "Open your developer settings. The key is on that page.",
    body: API_KEY_BODY
  )

  ensure_publish_state = lambda do |page_recording, slug:, status:, **attributes|
    current = page_recording.current_publishable
    if current && current.slug == slug && current.status == status
      next page_recording.publishable_child_recording
    end

    result = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: page_recording,
      actor: user,
      attributes: { slug: slug, status: status }.merge(attributes)
    )
    raise "Failed to set publish state: #{result.error}" if result.failure?

    result.value
  end

  ensure_publish_state.call(
    sign_in_page,
    slug: "how-do-i-sign-in",
    status: "published",
    seo_title: "How do I sign in?",
    seo_description: "Use the email and password you were given.",
    meta_robots: "index,follow"
  )
  ensure_publish_state.call(
    password_page,
    slug: "how-do-i-change-my-password",
    status: "draft"
  )
  ensure_publish_state.call(
    billing_page,
    slug: "how-do-i-update-payment-details",
    status: "published",
    seo_title: "How do I update payment details?",
    seo_description: "Open billing and save the card you want us to use."
  )
  ensure_publish_state.call(
    invoice_page,
    slug: "where-is-my-invoice",
    status: "published",
    seo_title: "Where is my invoice?",
    seo_description: "Open Billing, then Invoices. Download any paid invoice as a PDF."
  )
  ensure_publish_state.call(
    developers_page,
    slug: "where-do-i-find-my-api-key",
    status: "published",
    seo_title: "Where do I find my API key?",
    seo_description: "Open your developer settings. The key is on that page."
  )

  [sign_in_page, password_page, billing_page, invoice_page, developers_page].each do |support_recording|
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
puts "Seeded: Help sections Billing, Developers, Getting started"
puts "Seeded: Support pages 'How do I sign in?' (live) and 'How do I change my password?' (draft) under Getting started"
puts "Seeded: Billing pages 'How do I update payment details?' and 'Where is my invoice?' (both live)"
puts "Seeded: Admin root with owner access for admin@admin.com"
