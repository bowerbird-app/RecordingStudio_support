# Recording Studio Support

Staff write help pages. People help themselves. No tickets, no inbox, no chat.

Support pages sit under your workspace as a flat list. Each page has a title and a body. A page can hold images, go to trash, and sort those images. Staff use authenticated screens at `/support`, including a search box on the help list. An Admin Support section shows page counts, recent pages, and reads. This gem does not ship public pages, Publishable, public search, or an API yet.

## Install

Add the gem next to Recording Studio 4.2, Accessible, Admin 2.0, and the mixin gems Support pages use. GitHub hosting is not a reason to skip the gemspec pins.

```ruby
# Gemfile
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.6.1"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "2.0.0"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "0.4.0"
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "0.4.0"
gem "recording_studio_orderable", github: "bowerbird-app/RecordingStudio_orderable", tag: "0.2.0"
gem "recording_studio_support", github: "bowerbird-app/RecordingStudio_support"
```

```ruby
# gemspec / host Gemfile constraints
gem "recording_studio", "~> 4.2"
gem "recording_studio_accessible", "~> 0.6"
gem "recording_studio_admin", "~> 2.0"
gem "recording_studio_attachable", "~> 0.4"
gem "recording_studio_trashable", "~> 0.4"
gem "recording_studio_orderable", "~> 0.2"
```

Then:

```bash
bundle install
bin/rails generate recording_studio_support:install
bin/rails generate recording_studio_support:migrations
bin/rails generate recording_studio_attachable:migrations
bin/rails generate recording_studio_trashable:migrations
bin/rails generate recording_studio_orderable:migrations
bin/rails db:migrate
```

Install Active Storage if the host does not already have it. Images live as Attachable children, not in the page body.

The install generator mounts authenticated Support screens at `/support` and, when an `AdminRoot` model is present, enables `section :support`.

## Support pages

Register the type next to your host root. Dummy uses `Workspace`. Attachable registers its own image child type. Dummy also registers `AdminRoot` for staff admin.

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "AdminRoot",
    "RecordingStudioSupport::SupportPage"
  ]
  config.require_recordable_declarations = true
end
```

The page declares itself under that root and opts into the mixins. Installing the mixin gems does not turn this on for Folder or Page.

```ruby
recording_studio_recordable label: "Support page",
                            root: false,
                            allowed_parent_types: ["Workspace"]

include RecordingStudio::Capabilities::Attachable.to(
  allowed_content_types: ["image/*"],
  enabled_attachment_kinds: %i[image]
)
include RecordingStudio::Capabilities::Trashable.to
include RecordingStudio::Capabilities::Orderable.to(
  allows: ["RecordingStudioAttachable::Attachment"]
)
```

Create and change pages with public helpers. Do not insert Recording or Event rows by hand.

```ruby
root = RecordingStudio.root_recording_for(workspace)
page_recording = root.record(RecordingStudioSupport::SupportPage) do |page|
  page.title = "How do I sign in?"
  page.body = "Use the email and password you were given."
end

root.revise(page_recording) do |page|
  page.body = "Still stuck? Ask a teammate who already has access."
end

page_recording.import_attachment(
  io: image_file,
  filename: "sign-in.png",
  content_type: "image/png",
  actor: current_user
)

page_recording.recording_studio_orderable_reorder!(
  ordered_recording_ids: page_recording.recording_studio_orderable_children.map(&:id),
  actor: current_user
)

page_recording.recording_studio_trashable_trash!(actor: current_user)
page_recording.recording_studio_trashable_restore!(actor: current_user)
```

Authenticated screens call the same helpers. Access uses `grant_access` / `authorized?` on the workspace root (`:view` to read, `:edit` to write). This gem does not invent its own ACL.

Mount the screens and keep them on Recording Studio's default layout:

```ruby
mount RecordingStudioSupport::Engine, at: "/support"
```

Page reads are logs (`recording_studio_support_page_views`), not extra pages in the tree.

## Admin Support

Staff operations live on an **admin root**, not `user.admin?`. Grant Accessible access on that root. Enable the Support section:

```ruby
class AdminRoot < ApplicationRecord
  recording_studio_recordable label: "Admin", root: true, shared: false
  RecordingStudio.enable_capability(:accessible, on: self)
  include RecordingStudioAdmin::AllowsAdminSections

  recording_studio_admin_sections do
    section :support
  end
end
```

```ruby
mount RecordingStudioAccessible::Engine, at: "/admin/access"
recording_studio_admin_for :admin, at: "/admin", root_section: :support

RecordingStudioAccessible.bootstrap_owner_access!(
  recording: RecordingStudio.root_recording_for(admin_root),
  actor: first_staff_user
)
```

The section shows how many help pages you have, the latest pages, and how many times those pages were opened. Draft preview is the authenticated show — everything stays unpublished until Publishable exists.

## Dummy host

`test/dummy/` is a host that proves the gem. It is not the product.

Authenticated dummy pages use Recording Studio's shared default layout (`UsesDefaultLayout` / `recording_studio/default_layout`) so back/close chrome and Flatpack alerts come from core. Root Switchable and Sign out sit in that chrome. Devise sign-in keeps `layouts/application` and still loads Flatpack CSS/JS plus Turbo.

| Field    | Value           |
|----------|-----------------|
| Email    | admin@admin.com |
| Password | Password        |

Dummy kit pins:

| Gem | Pin |
|-----|-----|
| Recording Studio | `v4.2.0` |
| Accessible | `v0.6.1` |
| Admin | `2.0.0` |
| Attachable | `0.4.0` |
| Trashable | `0.4.0` |
| Orderable | `0.2.0` |
| Root Switchable | `v0.5.0` |
| FlatPack | `v0.1.133` |

```bash
cd test/dummy
bin/rails db:setup
bin/dev
```

Then open `/support` for help pages. Search the list with `?q=`. Dummy uses Flatpack's built-in `rounded` theme (`html data-theme="rounded"`). For `/admin`, pick **Admin** in the top workspace control first — Recording Studio Admin checks that the current root is the admin root.

## Engine internals

`docs/gem_template/` stays as engine-internal reference from the original addon template. This README is the product.
