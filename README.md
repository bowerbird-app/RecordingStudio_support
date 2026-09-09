# Recording Studio Support

Staff write help pages. People help themselves. No tickets, no inbox, no chat.

Help pages sit in a section under your workspace. Each page has a title and a formatted body. Pictures go in that body. A page can go to trash. Staff pick a section by moving the page. `/support` and `/support/sections/:id` are readable without signing in so visitors can browse sections and published pages. People with Accessible `:edit` also see **New section** and **New page** on that hub; write screens stay signed-in and Accessible-gated. Logged-out visitors can also read at `/help` (slug URLs) and live pages under a section. Drafts stay hidden. An Admin Support section is the hub for Edit, Move, and table-level New. This gem does not ship tickets, email, messaging, or an API.

## Install

Add the gem next to Recording Studio 4.2, Accessible, Admin 2.0, Publishable 0.2, and the mixin gems Support pages use. GitHub hosting is not a reason to skip the gemspec pins.

```ruby
# Gemfile
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.9.1"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.0.2"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.5.1"
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "0.4.0"
gem "recording_studio_orderable", github: "bowerbird-app/RecordingStudio_orderable", tag: "0.2.0"
gem "recording_studio_publishable", github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.2.0"
gem "recording_studio_icons", github: "bowerbird-app/RecordingStudio_icons"
gem "recording_studio_moveable", github: "bowerbird-app/RecordingStudio_moveable", tag: "3.0.0"
gem "recording_studio_support", github: "bowerbird-app/RecordingStudio_support"
# Host-owned auth (not a Support gemspec dependency):
gem "recording_studio_user", github: "bowerbird-app/RecordingStudio_users", tag: "v0.9.0"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.171"
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

Install Active Storage if the host does not already have it. Pictures upload through the Flatpack body editor and sit in the page HTML.

The install generator mounts Support screens at `/support` (section lists are public; write screens need sign-in), public help at `/help`, and Publishable at `/`. When an `AdminRoot` model is present, it enables `section :support`.

## Support pages

Register the type next to your host root and the Publishable child. Dummy uses `Workspace`. Dummy also registers `AdminRoot` for staff admin.

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "AdminRoot",
    "RecordingStudioUser::People",
    "RecordingStudioUser::Profile",
    "RecordingStudioSupport::SupportSection",
    "RecordingStudioSupport::SupportPage",
    "RecordingStudioAttachable::Attachment",
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

include RecordingStudio::Capabilities::Trashable.to
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

```

Authenticated screens call the same helpers. Access uses `grant_access` / `authorized?` on the workspace root (`:view` to read, `:edit` to write). Public read uses Publishable `indexable` / `indexable?`. This gem does not invent its own ACL.

Mount the screens. Public and staff help both use Recording Studio's default layout:

```ruby
mount RecordingStudioSupport::Engine, at: "/support"
mount RecordingStudioMoveable::Engine, at: "/recording_studio_moveable"
get "/help", to: RecordingStudioSupport::PublicPagesController.action(:index), as: :public_help
get "/help/sections/:slug", to: RecordingStudioSupport::PublicSectionsController.action(:show), as: :public_help_section
mount RecordingStudioPublishable::Engine, at: "/"
```

Declare the `/help` and `/help/sections/:slug` routes **before** the Publishable mount. Publishable also claims `/help/:uuid/:slug`, so a later section route never wins. Section URLs use a Support-owned `slug` (from the title). Old UUID bookmarks redirect to the slug URL. Staff `/support/sections/:id` stays on recording UUIDs.

Page reads are logs (`recording_studio_support_page_views`), not extra pages in the tree.

## Public help

Logged-out people can read sections and live pages. Drafts 404.

Public `/help` lists sections. A section show lists `SupportPage.indexable` pages in that section. Do not copy that logic. Public `/help?q=` and staff `/support?q=` search section names. Page search lives on a section show and filters pages **in that section** by title and body (`?q=`).

Public and staff Help **home** lists use Flatpack Search at full width (`max_width: :none`, placeholder “Search support”). Flatpack Search has no fill or height API; Support sets `--search-input-background-color` to `--color-white` and a visible border so the field reads as enabled instead of Flatpack’s muted default. Section rows on those homes share one Flatpack List with a trailing `chevron-right` icon, wrapped in a Card body, plus a Flatpack Badge with the published page count. Public `/help` passes `square_rows: true` — flush Card body (`padding: :none`) and Flatpack’s grouped square-corner class (`[&>*]:rounded-none`, same pattern as ButtonGroup / SegmentedButtons). Staff `/support` keeps the default Card padding and List::Item radius.

Public **section** show (`/help/sections/:slug`) is its own card stack — not the home `link_list` shape:

1. Default layout page nav — history Back, plus a PageNav **secondary** Home (home icon → `/help`, tooltip/aria `"Home"`). No Close
2. Flatpack PageTitle — section title, subtitle, `variant: :h1`
3. Flatpack Search — placeholder `Search in {section}…`, white input tokens as above
4. Flatpack Grid (`cols: 1`) of full-width elevated Cards (`href`, `clickable: true`, `hover: :strong`, `style: :elevated`) — title, muted plain-text snippet (~120 chars from the body; omitted when blank), Flatpack Timestamp from publish time (`publish_at`, then recording `updated_at`, then page `created_at`)
5. Optional host contact Card + secondary Button — only when `public_contact_href` is set
6. Flatpack EmptyState when the query matches nothing or the section has no live pages

Hosts that override `recording_studio/default_layout` (as the dummy does) should pass Flatpack `secondary_anchor_href` / `secondary_anchor_icon` / `secondary_anchor_tooltip` from `content_for` keys `page_nav_secondary_anchor_url`, `page_nav_secondary_anchor_icon`, and `page_nav_secondary_anchor_tooltip`. Map `page_nav_anchor_url` to Flatpack’s `anchor_href` (not the old `anchor_url`). Core `recording_studio_page_nav` does not yet forward secondary slots — Support’s public section show sets those `content_for` keys via `support_public_section_page_nav`.

No Published badge on public section cards (implied by indexable). Drafts stay off public `/help` lists. No Read / Open buttons. Staff `/support/sections/...` still uses the list + badge rules for editors vs visitors. Public and staff help use Recording Studio's default layout (`UsesDefaultLayout` / `recording_studio/default_layout`). Point Publishable `public_layout` at that layout. Do not use `recording_studio_publishable/application`. Put Flatpack's built-in rounded theme on `<html data-theme="rounded">` — core's body attribute is not enough. Dummy's default-layout override shows the host-side fix. Before Flatpack CSS, declare `@layer theme, base, components, utilities` so TipTap borders survive Tailwind preflight when `flat_pack/rich_text` loads before Tailwind.

Help titles come from `RecordingStudioSupport.configure`. Defaults stay “Help” / “Find an answer.” for public and staff, and “Pages people use when they get stuck.” for the admin section. Section blurbs and the optional contact slot are host-configurable:

```ruby
RecordingStudioSupport.configure do |config|
  config.pages_path = "/support"
  config.public_pages_path = "/help"
  config.help_title = "Help"
  config.help_subtitle = "Find an answer."
  config.public_help_title = "Help"
  config.public_help_subtitle = "Find an answer."
  config.admin_help_title = "Help"
  config.admin_help_subtitle = "Pages people use when they get stuck."
  config.public_section_subtitle = ->(section) {
    case section.slug
    when "billing" then "Payments, invoices, and plan changes."
    end
  }
  # Optional. Blank href keeps the gem chat-free (footer hidden).
  config.public_contact_href = nil
  config.public_contact_label = "Contact support"
end
```

When `public_section_subtitle` is blank or the callable returns blank, the section show uses `Find answers in {title}.`

Public show is Publishable's published route (`/help/:uuid/:slug`). It is a simple article: Flatpack `PageTitle`, optional Updated line, and long-form body in `prose` (Flatpack’s text/content pattern — there is no Content component). The document `<title>` is the page title. Meta description is plain text from the body (HTML stripped, entities decoded, max 160 characters). When the section has other published pages, a horizontal rule and Flatpack **Related** list follow the body. No live banner, no sign-in alert, no Edit, trash, or Access. Do not wrap the body in a skinny card.

Staff preview unpublished pages on the authenticated show. That is the same staff screen, not a second preview app. Staff show keeps Publish, a Live/Draft status button, and an icon-only trash control in the PageTitle row. It does not show a Pictures gallery.

The body editor is Flatpack `TextArea` with `rich_text: true`, `preset: :content`, and `uploads: { url: uploads_path }`. That upload endpoint is the same contract as ContentEditor (`upload_url` posts a file and returns `{ "url": "..." }`). `Body.sanitize` keeps `img` (`src`, `alt`).

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

The section is a hub with two tables: **Support pages** and **Support sections**. It shows a page-count number, not See every page or Latest pages. The pages table lists every page, draft or live, with search, Published/Draft, section, **Edit** and **Move** on each row, and **New page** at the top. The sections table has search, a **Count** column (`1` / `2` for every kept page in that section), **Edit**, and **New section**. That count is a Family Admin `column`, not a custom cell. Staff and public Help lists still show published counts only. Edit and New open the existing Support forms (`/support/new`, `/support/:id/edit`, `/support/sections/new`, `/support/sections/:id/edit`). Those forms use Save and Cancel as two Flatpack Buttons in one row. Move opens Moveable. The tables skip the default “Table data” heading and row count. Workspace `/support` is also a write hub for Accessible `:edit` users (**New section** / **New page**). Owner page preview stays read-only aside from Publish and trash. Do not put Edit on the owner preview.

Who can create, revise, publish, and trash — and what is still display-only or Admin-only — is spelled out in [docs/process-flows.md](docs/process-flows.md). Access stays Accessible on the workspace (and admin) root, not per page. Staff authorize checks that content’s workspace root (or AdminRoot) after the page/section is loaded, so an editor of one workspace cannot mutate another’s help by UUID.

## Dummy host

`test/dummy/` is a host that proves the gem. It is not the product.

Dummy help pages — public and staff — use Recording Studio's shared default layout (`UsesDefaultLayout` / `recording_studio/default_layout`) so back/close chrome and Flatpack alerts come from core. Dummy overrides that layout file only so Flatpack's built-in `rounded` theme sits on `<html data-theme="rounded">` (https://flatpack.bowerbird.io/). Core puts `data-theme` on `<body>` alone, which is not enough for component tokens. Support screens and Admin Support screens keep that chrome only. Dummy Sign out and Root Switchable stay on dummy host pages, not on `/support`, `/help`, or `/admin`. Access can stay on Admin. Do not put a login button there. Sign-in uses the Users gem (`recording_studio_user` `v0.9.0`): email at `/users/sign_in`, password at `/users/sign_in/password`, layout `recording_studio_user/auth` with `html data-theme="rounded"`. Help-page edit boots Flatpack's TipTap `TextArea` (`rich_text: true`, `preset: :content`, image upload); dummy Stimulus registers `flat-pack--tiptap` on first paint.

| Field    | Value           |
|----------|-----------------|
| Email    | admin@admin.com |
| Password | Password        |

Dummy kit pins:

| Gem | Pin |
|-----|-----|
| Recording Studio | `v4.2.0` |
| Accessible | `v0.9.1` |
| Admin | `v2.0.2` |
| Attachable | `v0.5.1` |
| Users | `v0.9.0` |
| Trashable | `0.4.0` |
| Orderable | `0.2.0` |
| Publishable | `v0.2.0` |
| Moveable | `3.0.0` |
| Root Switchable | `v0.5.0` |
| FlatPack | `v0.1.171` |

```bash
cd test/dummy
bin/rails db:setup
bin/dev
```

Then open `/help` or `/support` without signing in. Search the lists with `?q=`. Sign-in for write screens and Admin is Users gem two-step login. Dummy uses Flatpack's built-in `rounded` theme on `<html data-theme="rounded">` for Users auth, public help, staff help, and Admin. For `/admin`, pick **Admin** in the top workspace control first — Recording Studio Admin checks that the current root is the admin root. Edit and Move live on the Admin tables. New also appears on `/support` for editors, and on the Admin tables.

Seeds three sections: **Billing**, **Developers**, and **Getting started**. **How do I sign in?** is a live article with headings, a list, and an inline photograph. **How do I change my password?** stays a draft under Getting started. Billing has two live pages so Related links show on public article show; Developers has one.

## Cloud Agent boot

`.cursor/install.sh` runs at Cloud Agent Build. It runs `.cursor/fetch-skills.sh` last. To load a new pack, rebuild with Draft off. See [Cursor skills in Cloud Agents](docs/cursor-skills.md).

## Engine internals

`docs/gem_template/` stays as engine-internal reference from the original addon template. This README is the product.
