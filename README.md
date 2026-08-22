# Recording Studio Support

Staff write help pages. People help themselves. No tickets, no inbox, no chat.

Help pages sit in a section under your workspace. Each page has a title and a body. A page can hold images, go to trash, and sort those images. Staff pick a section by moving the page. Staff read sections and preview pages at `/support`. Logged-out visitors read sections at `/help` and live pages under a section. Drafts stay hidden. An Admin Support section is the hub. Staff open its help-pages table to see every page (draft and live) and to Edit, Move, or add New. Workspace `/support` is for reading and publish preview. This gem does not ship tickets, email, messaging, or an API.

## Install

Add the gem next to Recording Studio 4.2, Accessible, Admin 2.0, Publishable 0.2, and the mixin gems Support pages use. GitHub hosting is not a reason to skip the gemspec pins.

```ruby
# Gemfile
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.6.1"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "2.0.0"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "0.4.0"
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "0.4.0"
gem "recording_studio_orderable", github: "bowerbird-app/RecordingStudio_orderable", tag: "0.2.0"
gem "recording_studio_publishable", github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.2.0"
gem "recording_studio_icons", github: "bowerbird-app/RecordingStudio_icons"
gem "recording_studio_moveable", github: "bowerbird-app/RecordingStudio_moveable", tag: "3.0.0"
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
gem "recording_studio_publishable", "~> 0.2"
gem "recording_studio_moveable", "~> 3.0"
```

Then:

```bash
bundle install
bin/rails generate recording_studio_support:install
bin/rails generate recording_studio_support:migrations
bin/rails generate recording_studio_attachable:migrations
bin/rails generate recording_studio_trashable:migrations
bin/rails generate recording_studio_orderable:migrations
bin/rails generate recording_studio_publishable:install
bin/rails generate recording_studio_moveable:install
bin/rails db:migrate
```

Install Active Storage if the host does not already have it. Images live as Attachable children, not in the page body.

The install generator mounts authenticated Support screens at `/support`, public help at `/help`, and Publishable at `/`. When an `AdminRoot` model is present, it enables `section :support`.

## Support pages

Register the type next to your host root and the Publishable child. Dummy uses `Workspace`. Attachable registers its own image child type. Dummy also registers `AdminRoot` for staff admin.

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "AdminRoot",
    "RecordingStudioSupport::SupportSection",
    "RecordingStudioSupport::SupportPage",
    "RecordingStudioPublishable::Publishable"
  ]
  config.require_recordable_declarations = true
end
```

The page declares itself under that root and opts into the mixins. Installing the mixin gems does not turn this on for Folder or Page.

```ruby
recording_studio_recordable label: "Help section",
                            root: false,
                            allowed_parent_types: ["Workspace"]

include RecordingStudio::Capabilities::Trashable.to
include RecordingStudio::Capabilities::Orderable.to(
  allows: ["RecordingStudioSupport::SupportPage"]
)

recording_studio_recordable label: "Support page",
                            root: false,
                            allowed_parent_types: ["RecordingStudioSupport::SupportSection"]

include RecordingStudio::Capabilities::Attachable.to(
  allowed_content_types: ["image/*"],
  enabled_attachment_kinds: %i[image]
)
include RecordingStudio::Capabilities::Trashable.to
include RecordingStudio::Capabilities::Orderable.to(
  allows: ["RecordingStudioAttachable::Attachment"]
)
include RecordingStudio::Capabilities::Moveable.to
include RecordingStudio::Capabilities::Publishable.to(
  public_controller: "recording_studio_support/public_pages",
  public_action: :show,
  public_layout: "recording_studio/default_layout",
  path: "/help/:uuid/:slug"
)
```

Create and change pages with public helpers. Publish with Publishable's Update helper. Do not insert Recording or Event rows by hand.

```ruby
root = RecordingStudio.root_recording_for(workspace)
section = root.record(RecordingStudioSupport::SupportSection) do |item|
  item.title = "Getting started"
end
page_recording = root.record(
  RecordingStudioSupport::SupportPage,
  parent_recording: section
) do |page|
  page.title = "How do I sign in?"
  page.body = "Use the email and password you were given."
end

page_recording.move_to!(new_parent: other_section, actor: current_user)

root.revise(page_recording) do |page|
  page.body = "Still stuck? Ask a teammate who already has access."
end

RecordingStudioPublishable::Services::Publishables::Update.call(
  parent_recording: page_recording,
  actor: current_user,
  attributes: { slug: "how-do-i-sign-in", status: "published" }
)

page_recording.import_attachment(
  io: image_file,
  filename: "sign-in.png",
  content_type: "image/png",
  actor: current_user
)
```

Authenticated screens call the same helpers. Access uses `grant_access` / `authorized?` on the workspace root (`:view` to read, `:edit` to write). Public read uses Publishable `indexable` / `indexable?`. This gem does not invent its own ACL.

Mount the screens. Public and staff help both use Recording Studio's default layout:

```ruby
mount RecordingStudioSupport::Engine, at: "/support"
mount RecordingStudioMoveable::Engine, at: "/recording_studio_moveable"
get "/help", to: RecordingStudioSupport::PublicPagesController.action(:index), as: :public_help
get "/help/sections/:id", to: RecordingStudioSupport::PublicSectionsController.action(:show), as: :public_help_section
mount RecordingStudioPublishable::Engine, at: "/"
```

Declare the `/help` and `/help/sections/:id` routes **before** the Publishable mount. Publishable also claims `/help/:uuid/:slug`, so a later section route never wins.

Page reads are logs (`recording_studio_support_page_views`), not extra pages in the tree.

## Public help

Logged-out people can read sections and live pages. Drafts 404.

Public `/help` lists sections. A section show lists `SupportPage.indexable` pages in that section. Do not copy that logic. Public `/help?q=` and staff `/support?q=` search section names. Page search lives on a section show. Both lists use Flatpack Search at full width (`max_width: :none`). Public and staff help use Recording Studio's default layout (`UsesDefaultLayout` / `recording_studio/default_layout`). Point Publishable `public_layout` at that layout. Do not use `recording_studio_publishable/application`.

Help titles come from `RecordingStudioSupport.configure`. Defaults stay “Help” / “Answers you can share.” for staff, “Answers you can read.” for public, and “Pages people use when they get stuck.” for the admin section.

```ruby
RecordingStudioSupport.configure do |config|
  config.pages_path = "/support"
  config.public_pages_path = "/help"
  config.help_title = "Help"
  config.help_subtitle = "Answers you can share."
  config.public_help_title = "Help"
  config.public_help_subtitle = "Answers you can read."
  config.admin_help_title = "Help"
  config.admin_help_subtitle = "Pages people use when they get stuck."
end
```

Public show is Publishable's published route (`/help/:uuid/:slug`). It renders Support's public page template. Last updated comes from the publishable `publish_at` time.

Staff preview unpublished pages on the authenticated show. That is the same staff screen, not a second preview app.

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

The section is a hub: sections (list + New), latest pages, plus **See every page**. It does not show vanity totals. The help-pages screen is the job — a Flatpack table of every page, draft or live, with search, Published/Draft, section, **Edit** and **Move** on each row, and **New** at the top. Edit and New open the existing Support page forms (`/support/new`, `/support/:id/edit`). Move opens Moveable. The table skips the default “Table data” heading and row count. Workspace `/support` and owner preview stay for reading and publish preview. Do not put Edit on the owner preview.

## Dummy host

`test/dummy/` is a host that proves the gem. It is not the product.

Dummy help pages — public and staff — use Recording Studio's shared default layout (`UsesDefaultLayout` / `recording_studio/default_layout`) so back/close chrome and Flatpack alerts come from core. Support screens and Admin Support screens keep that chrome only. Dummy Sign out and Root Switchable stay on dummy host pages, not on `/support`, `/help`, or `/admin`. Access can stay on Admin. Do not put a login button there. Devise sign-in keeps `layouts/application` and still loads Flatpack CSS/JS plus Turbo. Help-page edit boots Flatpack's TipTap `TextArea` (`rich_text: true`); dummy Stimulus registers `flat-pack--tiptap` on first paint.

Public and staff help use core’s default layout, so `rounded` lands on `<body>`.

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
| Publishable | `v0.2.0` |
| Moveable | `3.0.0` |
| Root Switchable | `v0.5.0` |
| FlatPack | `v0.1.133` |

```bash
cd test/dummy
bin/rails db:setup
bin/dev
```

Then open `/help` without signing in, or `/support` after you sign in. Search the staff list with `?q=`. Dummy uses Flatpack's built-in `rounded` theme (`html data-theme="rounded"`). For `/admin`, pick **Admin** in the top workspace control first — Recording Studio Admin checks that the current root is the admin root. Edit, Move, and New live on the Admin help-pages table, not on owner preview.

Seeds three sections: **Billing**, **Developers**, and **Getting started**. **How do I sign in?** is live and **How do I change my password?** stays a draft under Getting started. Billing and Developers each have one live page so those lists are not empty.

## Engine internals

`docs/gem_template/` stays as engine-internal reference from the original addon template. This README is the product.
