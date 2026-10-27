# Recording Studio Support

Staff write help pages. People help themselves at `/help`. Signed-in users and staff talk on a Messages desk under the support mount.

Help pages sit in a section under your workspace. Each page has a title and a formatted body. Pictures go in that body. A page can go to trash. Staff pick a section by moving the page. Staff land in **Admin Support** (`/admin`). Write, preview, Publish, and uploads live under `/admin/support`. Access is Admin plus Accessible on the admin root — not a workspace `:edit` grant. Logged-out visitors read at `/help` (slug URLs) and live pages under a section. Drafts stay hidden. Signed-in people open `/help/messages`; staff open `/admin/support/messages`. Both desks render the Messages gem chat partial — do not fork Chat::Layout or Chat::Panel. JSON for sections and pages is optional: add Recording Studio API in the **host** (dummy does). Gates stay Accessible. Endpoints: [docs/api.md](docs/api.md).

## Install

Add the gem next to Recording Studio 6.1, Accessible 0.19.1, Admin 2.7, Publishable 0.12, Flatpack 0.1.319, and the mixin gems Support pages use. GitHub hosting is not a reason to skip the gemspec pins. ViewComponent stays on `>= 4.14, < 5` (this repo locks `4.19.0`).

```ruby
# Gemfile
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.1.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.19.1"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.7.0"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.15.0"
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.12.0"
gem "recording_studio_orderable", github: "bowerbird-app/RecordingStudio_orderable", tag: "v0.4.0"
gem "recording_studio_publishable", github: "bowerbird-app/RecordingStudio_publishable", tag: "v0.12.0"
gem "recording_studio_icons", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.1.1"
gem "recording_studio_moveable", github: "bowerbird-app/RecordingStudio_moveable", tag: "v3.4.3"
gem "recording_studio_messages", github: "bowerbird-app/RecordingStudio_messages", tag: "v0.9.0"
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.5.0"
gem "recording_studio_logs", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.5.0"
gem "recording_studio_views", github: "bowerbird-app/RecordingStudio_views", tag: "v0.8.0"
gem "recording_studio_notifications", github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.7.0"
gem "recording_studio_notifications_email",
    github: "bowerbird-app/RecordingStudio_notifications_email", tag: "v0.3.4"
gem "recording_studio_search", "~> 0.6",
    github: "bowerbird-app/RecordingStudio_search", tag: "v0.6.0"
gem "recording_studio_support", github: "bowerbird-app/RecordingStudio_support"
# Host-owned auth (not a Support gemspec dependency):
gem "recording_studio_user", github: "bowerbird-app/RecordingStudio_users", tag: "v0.21.0"
gem "flat_pack", github: "bowerbird-app/flatpack", ref: "1fcbafe94f8eb118f0a22182f63f5110fcc97a56" # 0.1.319
gem "view_component", "4.19.0"
```

```ruby
# gemspec / host Gemfile constraints
gem "recording_studio", ">= 6.1.0"
gem "flat_pack", ">= 0.1.315"
gem "view_component", ">= 4.14", "< 5"
gem "recording_studio_accessible", "~> 0.11"
gem "recording_studio_admin", "~> 2.0"
gem "recording_studio_attachable", "~> 0.7"
gem "recording_studio_trashable", "~> 0.9"
gem "recording_studio_orderable", "~> 0.2"
gem "recording_studio_publishable", "~> 0.4"
gem "recording_studio_search", "~> 0.6"
gem "recording_studio_moveable", "~> 3.2"
gem "recording_studio_messages", "~> 0.5"
gem "recording_studio_metrics", ">= 0.5.0", "< 1.0"
gem "recording_studio_views", ">= 0.8.0", "< 0.9"
gem "recording_studio_notifications", ">= 0.3.1", "< 1"
gem "recording_studio_notifications_email", "~> 0.3.1"
```

Latest tags of Attachable, Logs, Metrics, Moveable, Notifications, Notifications Email, Search, Views, Cache, Users, Root Switchable, Internationalization, API, and Accessible still require `recording_studio` below 6. This repo's Gemfiles load `test/support/widen_recording_studio_requirement.rb` before the gemspec so Bundler can resolve `6.1.0`. That file is not part of the installed gem. A host Gemfile that includes one of those gems has to widen the requirement the same way. Messages `v0.9.0`, Publishable `v0.12.0`, Orderable `v0.4.0`, Trashable `v0.12.0`, Admin `v2.7.0`, and Recording Studio `v6.1.0` already allow `6.1.0`. Orderable `v0.4.0`, Trashable `v0.12.0`, and Moveable `v3.4.3` drop `RecordingStudio::UsesDefaultLayout`, which Recording Studio 6.1 removed. Earlier tags make `CI=true` eager load raise `NameError`. Admin screens need Admin `v2.7.0` because earlier releases still call `recording_studio_page_nav`. Accessible stays on `v0.19.1`: `0.20` and later reject Messages `v0.9.0`'s first-owner `grant_access` (`You can only grant a role you already hold`). Attachable stays on `v0.15.0` and Notifications stays on `v0.7.0`: later releases need schema changes this dummy does not ship. Root Switchable `v0.10.0` drops `anchor_label`; its gemspec still caps Recording Studio below 5, so the widen hook stays.

Then:

```bash
bundle install
bin/rails generate recording_studio_search:install
bin/rails generate recording_studio_messages:install
bin/rails generate recording_studio_notifications:install
bin/rails generate recording_studio_notifications_email:install
bin/rails generate recording_studio_support:install
bin/rails generate recording_studio_support:migrations
bin/rails generate recording_studio_logs:migrations
bin/rails generate recording_studio_views:install
bin/rails generate recording_studio_views:migrations
bin/rails generate recording_studio_messages:migrations
bin/rails generate recording_studio_notifications:migrations
bin/rails generate recording_studio_attachable:migrations
bin/rails generate recording_studio_trashable:migrations
bin/rails generate recording_studio_orderable:migrations
bin/rails generate recording_studio_publishable:install
bin/rails generate recording_studio_moveable:install
bin/rails generate recording_studio_accessible:migrations
bin/rails db:migrate
```

Accessible `v0.11` stores roles as strings (`view`, `edit`, `admin`) and adds access invitations. Accessible `v0.14` adds access constraint and access rule tables for optional action audiences. Run its 0.8–0.14 migrations (0.15 is translation-only). Grant through `bootstrap_owner_access!` / `grant_access` — do not create `RecordingStudio::Access` rows. Dummy pins API `v0.7.0`. For operations move and trash by an AdminRoot-only client, the **host** sets Trashable and Moveable hooks (Support does not). `nil` falls through to Accessible `:edit`:

```ruby
RecordingStudioTrashable.configure do |config|
  config.authorization_resolver = lambda do |actor:, recording:, **|
    RecordingStudioSupport.staff_permission(actor: actor, recording: recording)
  end
end

RecordingStudio::Moveable.configure do |config|
  config.use_builtin_access = true
  config.authorization_hook = lambda do |actor:, source:, destination:, **|
    source_ok = RecordingStudioSupport.staff_permission(actor: actor, recording: source)
    destination_ok = RecordingStudioSupport.staff_permission(actor: actor, recording: destination)
    next true if source_ok && destination_ok

    nil
  end
end
```

Keep Search `default_backend = :pg_trgm`. Do not run `searchable_pgvector` for Support in this phase. `SupportPage` is already declared searchable (title weight A, body weight D). Allowlist only that model for Instant UI (`config.instant_search_models = ["RecordingStudioSupport::SupportPage"]`). Mount `RecordingStudioSearch::Engine` at `/recording_studio_search`, pin `controllers/recording_studio_search`, and `eagerLoadControllersFrom` it. Public section Instant hits `/help/sections/:slug/instant_search` (same trigram, live pages in that section). Staff section Instant hits `/admin/support/sections/:id/instant_search`. `/help?q=` stays a GET form on section titles.

Install Active Storage if the host does not already have it. Pictures upload through the Flatpack body editor and sit in the page HTML.

The install generator mounts staff Support screens at `/admin/support`, public help at `/help`, and Publishable at `/`. Old `/support` bookmarks redirect to `/admin`. When an `AdminRoot` model is present, it enables `section :support`.

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
    "RecordingStudioSupport::SupportTicket",
    "RecordingStudioMessages::MessageMount",
    "RecordingStudioMessages::MessageGroup",
    "RecordingStudioMessages::Message",
    "RecordingStudioAttachable::Attachment",
    "RecordingStudioAttachable::Library",
    "RecordingStudioAttachable::Placement",
    "RecordingStudioPublishable::Publishable"
  ]
  config.require_recordable_declarations = true
end
```

Enable Messages on the workspace (mount parent, key `:support` — not AdminRoot). Lock membership so ticket conversations cannot invite people from the chat UI:

```ruby
class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
  RecordingStudio.enable_capability(:accessible, on: self)
  include RecordingStudio::Capabilities::Messages.to(
    keys: [:support],
    membership_locked: [:support]
  )
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
  item.icon = "rocket-launch" # optional Heroicons name; blank skips the glyph on /help
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

Authenticated screens call the same helpers. Staff access uses `grant_access` / `authorized?` on the **admin root**. Public read uses Publishable `indexable` / `indexable?`. This gem does not invent its own ACL.

Mount the screens. Public help and staff forms both use Recording Studio's default layout. Mount Support **before** Admin so `/admin/support` is not swallowed by `/admin`:

```ruby
mount RecordingStudioAccessible::Engine, at: "/admin/access"
mount RecordingStudioMessages::Engine, at: "/recording_studio_messages"
mount RecordingStudioNotifications::Engine, at: "/recording_studio_notifications"
mount RecordingStudioSupport::Engine, at: "/admin/support"
recording_studio_admin_for :admin, at: "/admin", root_section: :support
mount RecordingStudioMoveable::Engine, at: "/recording_studio_moveable"
get "/help", to: RecordingStudioSupport::PublicPagesController.action(:index), as: :public_help
get "/help/messages", to: RecordingStudioSupport::UserMessagesController.action(:show), as: :help_messages
get "/help/sections/:slug", to: RecordingStudioSupport::PublicSectionsController.action(:show), as: :public_help_section
get "/help/sections/:slug/instant_search",
    to: RecordingStudioSupport::PublicInstantSearchesController.action(:show),
    as: :public_help_section_instant_search
mount RecordingStudioSearch::Engine, at: "/recording_studio_search"
mount RecordingStudioPublishable::Engine, at: "/"
get "/support", to: redirect("/admin")
get "/support/*legacy_support_path", to: redirect("/admin")
```

Declare the `/help` and `/help/sections/:slug` routes **before** the Publishable mount. Publishable also claims `/help/:uuid/:slug`, so a later section route never wins. Section URLs use a Support-owned `slug` (from the title). Old UUID bookmarks redirect to the slug URL. Staff forms under `/admin/support/sections/:id` stay on recording UUIDs.

Help page opens are Recording Studio Views raw logs (`RecordingStudioViews::ViewLog`), not extra pages in the tree and not Support’s old `recording_studio_support_page_views` table. Enable `:viewable` on `SupportPage` (Support does this), mount Views, put `<%= recording_studio_track_views %>` in the shared layout **body**, and pin `recording_studio_views/collector`. Implement public `current_recording` (Views’ default resolver) so it returns the help page on staff show and on Publishable’s public renderer (`@parent_recording` / `@recording`). Public visitors need the Accessible `tracking_access_action` Views uses (`:"recording_studio_views.view"` with a public audience). After upgrade, copy leftover Support rows with `bin/rails recording_studio_support:backfill_page_views`. Do not drop the old table in 0.25.0. Schedule Logs jobs (`DailyAggregationJob`, `ReconciliationJob`, `RetentionCleanupJob`, `BackfillJob`) and `RecordingStudioViews::ReceiptCleanupJob`. Optional MaxMind geo follows the Views README.

## Public help

Logged-out people can read sections and live pages. Drafts 404.

Public `/help` lists sections. A section show lists `SupportPage.indexable` pages in that section. Do not copy that logic. Public `/help?q=` searches section title and slug via `SupportSection.search` (Recording Studio Search `pg_trgm`) with a GET form. Page search lives on a public section show and filters pages **in that section** via Recording Studio Search trigram on title/body. Typing uses Search Instant UI (`instant_search_field` + Turbo Frame) against the section Instant path; Enter / no-JS still GET `?q=` on the section. Staff section show uses the same Instant field against the staff Instant path. The Search engine Instant endpoint is mounted for hosts; Support filters it to **live** `SupportPage` rows so drafts do not leak. Search `v0.6.0` inherits the host `ApplicationController`, so hosts that require sign-in there will require it on the engine Instant path too — public `/help` Instant stays on Support’s public Instant controller. Admin support pages and sections table search use the same Search-backed `apply_query` helpers.

Public `/help` and public section show use Flatpack Search at full width (`max_width: :none`, placeholder from `recording_studio.support.help.search_placeholder`, English “Search support”). Support sets `--search-input-background-color` to `--color-white` and a visible border so the field reads as enabled instead of Flatpack’s muted default. Public `/help` and public section show pass `size: :lg` (Flatpack `0.1.175+`). Public `/help` also raises the `:lg` vertical padding (`prominent: true`). Staff search on remaining engine screens keeps the default `:md`. Passing `placeholder:` still overrides the locale.

**Public `/help` home** sets `content_for :title` to `public_help_title`. The default layout draws that string as the only `h1`. There is no subtitle on this page. Section cards are a Grid (`cols: 3`, `gap: :lg`) of clickable Cards (`background: :default`, `border: :default`, `shadow: :sm`, `hover: :strong`, body `padding: :lg`). Each card shows an optional Heroicons glyph (section `icon` short name via Flatpack `IconComponent`) to the left of the section title and a muted **N article(s)** line (no Badge). Blank icon skips the glyph. Staff section and page forms preview the glyph live beside the Icon field. New pages default to the parent section’s icon.

**Staff hub** is Admin Support tables at `/admin`, not a `/support` list. Engine `/admin/support` redirects there. Write, preview, Publish, and trash stay under `/admin/support…`.

Public **section** show (`/help/sections/:slug`) is its own card stack — not the home `link_list` shape:

1. `flat_pack_page_nav(round: true, style: :default, back_href: /help, back_tooltip: Home)`. No Close
2. Layout `PageTitle` from `content_for :title` and `content_for :subtitle`
3. Search Instant field (`instant_search_field`) — `size: :lg`, placeholder `Search in {section}…`, white input tokens as above; results update in Turbo Frame `support_page_search_results`
4. Flatpack Grid (`cols: 1`, `gap: :lg`) of full-width Cards (`href`, `clickable: true`, `hover: :strong`, `background: :default`, `border: :default`, `shadow: :sm`) — Body padding `:lg`, title, muted plain-text snippet (~120 chars from the body; omitted when blank), Flatpack Timestamp from publish time (`publish_at`, then recording `updated_at`, then page `created_at`)
5. Optional host contact Card + secondary Button — only when `public_contact_href` is set (inside the Instant results frame so Instant updates keep it in sync), spaced below the article Grid (`mt-10`). The Button uses `data-turbo-frame="_top"` so the desk loads as a full page
6. Flatpack EmptyState when the query matches nothing or the section has no live pages — search no-results copy is `Try another keyword or {contact link}.` (underlined Flatpack Link inline, also `data-turbo-frame="_top"`; no Button slot, no bottom Card)

Public **article** show (`/help/:uuid/:slug`) ends with the same optional contact Card + secondary Button when `public_contact_href` is set (prompt via `support_public_contact_prompt` for the parent section). Public `/help?q=` with no section hits uses the same EmptyState Contact Button in its `slot`.

`RecordingStudioSupport.configuration.layout` defaults to `nil`. `nil` uses `RecordingStudio.configuration.layout`, then `"recording_studio/default_layout"`. `false` renders no layout. A String is a layout name. A callable must be keyword-only, `->(controller:) { ... }`, and return a String, `nil`, or `false`. Any other value raises `ArgumentError` from `RecordingStudio::Layout.accept`.

```ruby
RecordingStudioSupport.configure do |config|
  config.layout = nil
end
```

Support controllers call `recording_studio_layout { RecordingStudioSupport.configuration.layout }`. Do not include `RecordingStudio::UsesDefaultLayout`. Do not write `layout "recording_studio/default_layout"` in a controller. `rake recording_studio:check_layouts` fails that call.

Page chrome is `content_for :title`, optional `content_for :subtitle`, and `flat_pack_page_nav(round: true, style: :default, back_href:, back_tooltip:, anchor_href:, anchor_tooltip:)`. Action links use `register_page_nav "Label", path, role: :primary` (`:secondary` or `:destructive`). Custom HTML to the left of that button group uses `recording_studio_page_nav_right` or `content_for :page_nav_right`. `recording_studio_page_nav` and the old `:page_nav_back_*` / `:page_nav_anchor_*` slots are gone. Public section show still goes Home through `back_href`. A public article uses `anchor_icon: "home"` for the same place.

Interactive + `hover: :strong` needs a host Tailwind utilities-layer override for the border color change: Flatpack’s hover rules live in `@layer components`, but the card also applies Tailwind’s `border-[var(--card-border-color)]` utility, and utilities win on hover. Dummy’s `app/assets/tailwind/application.css` shows the override hosts should copy until Flatpack moves those hover rules.

No Published badge on public section cards (implied by indexable). Drafts stay off public `/help` lists. No Read / Open buttons. Public help uses `recording_studio/default_layout`. Point Publishable `public_layout` at that layout. Do not use `recording_studio_publishable/application`. Core puts `data-theme="rounded"` on `<html>`. Load `flat_pack/variables`, `flat_pack/application`, and `flat_pack/rich_text` before the Tailwind sheet. Declare `@layer theme, base, components, utilities` before those sheets so TipTap borders survive Tailwind preflight.

Help titles come from `RecordingStudioSupport.configure`. Staff engine defaults stay “Help” / “Find an answer.” The Admin Support hub title (`admin_help_title`) defaults to **Support**. Public default title is **Hi, how can we help?** (`public_help_subtitle` remains configurable but the shipped `/help` home does not render it). Admin section default subtitle is “Pages people use when they get stuck.” Section blurbs and the optional contact slot are host-configurable:

```ruby
RecordingStudioSupport.configure do |config|
  config.pages_path = "/admin/support"
  config.public_pages_path = "/help"
  config.help_title = "Help"
  config.help_subtitle = "Find an answer."
  config.public_help_title = "Hi, how can we help?"
  config.public_help_subtitle = "Find an answer."
  config.admin_help_title = "Support"
  config.admin_help_subtitle = "Pages people use when they get stuck."
  config.public_section_subtitle = ->(section) {
    case section.slug
    when "billing" then "Payments, invoices, and plan changes."
    end
  }
  # Default contact button points at the signed-in desk.
  config.public_contact_href = "/help/messages"
  config.public_contact_label = "Contact support"
  # Staff set for the messages desk (grants, staff desk, notices).
  # When set, only this email is staff. When blank, `messages_admin_finder`
  # runs (default: User.where(admin: true)).
  # config.messages_admin_email = "support@example.com"
  # config.messages_admin_finder = -> { User.where(admin: true) }
end
```

## Messages desk

Tickets own the conversation lifecycle. Each ticket creates a MessageGroup under the Workspace `:support` mount (global — not per AdminRoot). Public `/help` stays anonymous with no composer. Existing per-user MessageGroups are not migrated.

| Desk | Path | Who |
|---|---|---|
| User list | `GET /help/messages` | Signed-in user (auth required) |
| User new | `GET /help/messages/new` + `POST /help/messages` | Signed-in user |
| User show | `GET /help/messages/:id` | Ticket owner (or staff) |
| Staff | `GET /admin/support/messages` | Signed-in staff |
| Staff ticket | `PATCH /admin/support/tickets/:id` | Signed-in staff (status / assignee) |

**Staff set** (`messages_admin_email`): when set to an email, only that user is staff. When blank, `messages_admin_finder` runs — default `User.where(admin: true)` (or your host finder). Same set for `:edit` grants on each conversation, staff desk access, and staff notifications.

Opening a ticket runs `Tickets.open!`: a MessageGroup under `:support`, then `RecordingStudio.record!` for one `SupportTicket` child of that group (`subject`, `priority`, status `open`), staff `:edit` grants (via `allow_membership_change`), and the first message. A second ticket on the same group raises `Tickets::AlreadyExists`. Users list their tickets instead of a singleton group. Staff join the current ticket onto the selected group and edit status, priority, and assignee with `Tickets.update!`, which revises the recording. The desk URL keeps the id it was opened with. `Tickets.find!` resolves a recording id or an older snapshot id to the current ticket. Status values: `open`, `waiting_on_customer`, `waiting_on_support`, `resolved`. Priority: `low`, `normal`, `high`. Assignee is optional.

The Workspace `:support` mount is **membership locked** (`membership_locked: [:support]`). Ticket panels hide **+ Access** / avatars; Accessible manage/grant/update/revoke on those conversations is denied unless wrapped in `RecordingStudioMessages.allow_membership_change` (Support’s staff sync already does this).

Both desks render `recording_studio_messages/message_groups/desk` only — do not fork Chat::Layout or Chat::Panel. The panel is a Turbo frame; Support prepends Accessible's access button so "+ Access" uses `data-turbo-frame="_top"` and the access page loads in full. Each desk opens with a Flatpack PageTitle (`Messages` for the user desk, `Support messages` for staff). Keep `data-theme="rounded"` on `<html>` and add Tailwind `@source` lines for Messages views.

`public_contact_href` defaults to `/help/messages`. Logged-out visitors who click Contact hit sign-in.

When `public_section_subtitle` is blank or the callable returns blank, the section show uses `Find answers in {title}.`

Public show is Publishable's published route (`/help/:uuid/:slug`). Header order is Flatpack Badge (section title, stock `size: :lg`, wrapped in `w-fit` so it stays an inline chip) → larger centered `PageTitle` (`--page-title-h1-size: var(--text-5xl)`, `class: "text-center"`; wrapped to cancel stock `mb-6`) whose subtitle is the calendar day via `support_page_updated_on` (not the page `description`, and not relative “N ago”). Long-form body renders through `FlatPack::Content::Component` (`class: "mt-8 mb-8 pb-8"`) so article type uses the kit 18px reading scale. `support_page_body_html` still sanitizes and remaps images, lists, and tips inside that wrapper. Inline pictures are lifted out of wrapping `<p>` tags into full-width `<figure>` / `<img>`. Body `ol`/`ul` render through Flatpack `List` with dense spacing and prose-tight list rows (Flatpack `List::Item` padding is skipped so steps are not spaced like interactive nav); wrap tip copy in `blockquote` so nested lists still go through Flatpack (tip text uses the same surface content color as the article). The document `<title>` is the page title. Meta description prefers the page `description` when set; otherwise plain text from the body (HTML stripped, entities decoded, max 160 characters). There is no Related list. PageNav backs to the section (or `/help`) and offers Home to `/help` (no Close). No live banner, no sign-in alert, no Edit, trash, or Access. Do not wrap the title stack or body in an extra card.

Staff preview unpublished pages on the authenticated show at `/admin/support/:id`. That is the same staff screen, not a second preview app. Staff show keeps Publishable QuickActions (Draft, a scheduled date, or Published) and an icon-only trash control in the PageTitle row. Publish now, Schedule, Unpublish, Preview or View, SEO, and Social live in that menu. It does not show a Pictures gallery.

The body editor is Flatpack `TextArea` with `rich_text: true`, `preset: :content`, and `uploads: { url: uploads_path }`. That upload endpoint is the same contract as ContentEditor (`upload_url` posts a file and returns `{ "url": "..." }`). `Body.sanitize` keeps `img` (`src`, `alt`). Staff forms also take an optional plain **Description** summary above Body.

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

The section is a hub with **Support pages**, **Support sections**, **Open tickets**, **Time to close**, and **Help page views**. It shows a page-count number, plus Metrics widgets for unassigned open tickets, oldest open ticket age, average time to resolve, and help page views over time. Unassigned tickets opens Open tickets filtered to Unassigned. Oldest open ticket opens that table of `status: open` rows, oldest first. Time to close and Help page views open matching screens with a chart and a table. Those two screens keep Date range and Group by inline (not in the filter modal). Date range bounds the rows; group by buckets the chart by day, week, or month. The Help page views hub widget hides x-axis labels. It does not show See every page or Latest pages. The pages table lists every page, draft or live, with search, Published/Draft, section, **Edit** and **Move** on each row, and **New page** at the top. The sections table has search, a **Count** column (`1` / `2` for every kept page in that section), **Edit**, and **New section**. That count is a Family Admin `column`, not a custom cell. Public Help lists still show published counts only. Edit and New open the existing Support forms (`/admin/support/new`, `/admin/support/:id/edit`, `/admin/support/sections/new`, `/admin/support/sections/:id/edit`). Those forms use Save and Cancel as two Flatpack Buttons in one row. Move opens Moveable. The tables skip the default “Table data” heading and row count. Owner page preview stays read-only aside from the publish dropdown and trash. Do not put Edit on the owner preview.

Who can create, revise, publish, and trash is spelled out in [docs/process-flows.md](docs/process-flows.md). Access stays Accessible on the **admin root**, not per page and not via workspace-only `:edit`. Logged-out people and workspace editors without an AdminRoot grant cannot use `/admin/support`.

## JSON API

Support does not gemspec-depend on `recording_studio_api`. If the host adds that gem, Support registers **public** page reads and **operations** section reads plus writes. Operations `SupportPage` `operations:` include those writes so MCP `describe` matches `PATCH`.

Full contract for hosts and AI agents: **[docs/api.md](docs/api.md)** (auth, fields, search, examples). Design notes: [docs/api-plan.md](docs/api-plan.md).

Public keeps only `GET support_pages` and `GET support_pages/:id`. Those use `:view` on the workspace that owns the page, or on the admin root. Admin-root readers see drafts. Workspace-only readers see live/`indexable` pages, matching `/help`.

Section list/show and nested section-page reads live on `/recording_studio_api/apis/operations/v1/…` and authorize Accessible `:view` on the **admin root** (`can_view_as_staff?`). Writes (`create` / `update` / trash / move / publish / unpublish) stay on operations and still need AdminRoot `:edit` — the same bar as `authorize_support!(:edit)`. A public token is rejected there. An operations actor without AdminRoot `:edit` is `403` on writes.

Bearer token: public `POST /recording_studio_api/oauth/token`; operations `POST /recording_studio_api/apis/operations/oauth/token` (`client_credentials`), then `Authorization: Bearer …`.

| Method | Path |
| --- | --- |
| `GET` | `/recording_studio_api/api/v1/support_pages` |
| `GET` | `/recording_studio_api/api/v1/support_pages/:id` |
| `GET` | `/recording_studio_api/apis/operations/v1/support_sections` |
| `GET` | `/recording_studio_api/apis/operations/v1/support_sections/:id` |
| `GET` | `/recording_studio_api/apis/operations/v1/support_sections/:parent_id/pages` |
| `GET` | `/recording_studio_api/apis/operations/v1/support_sections/:parent_id/pages/:relationship_id` |
| `POST` `PATCH` `DELETE` | `/recording_studio_api/apis/operations/v1/support_sections` |
| `POST` `PATCH` `DELETE` | `/recording_studio_api/apis/operations/v1/support_sections/:parent_id/pages` |
| `POST` `PATCH` `DELETE` | `/recording_studio_api/apis/operations/v1/support_pages` |
| `POST` | `/recording_studio_api/apis/operations/v1/support_pages/:id/actions/move` |
| `POST` | `/recording_studio_api/apis/operations/v1/support_pages/:id/actions/publish` |
| `POST` | `/recording_studio_api/apis/operations/v1/support_pages/:id/actions/unpublish` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_tickets/open` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_tickets/unassigned_open` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_tickets/oldest_open_age` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_tickets/by_status` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_tickets/by_priority` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_tickets/opened` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_tickets/avg_time_to_resolve` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_pages/total` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_page_views/over_time` |

Support registers those metrics with Recording Studio Metrics. The host exposes them once:

```ruby
RecordingStudioMetrics::Api.register!(api: :operations)
```

Staff with AdminRoot `:view` can read them. A public token or a non-admin operations token is denied. `support_pages.total` counts live page recordings (`Admin::Queries.kept_page_recordings`), not SupportPage snapshots. Ticket metrics count the current snapshot of each ticket recording (joined to `recording_studio_support_tickets` on `recordable_id`, type `RecordingStudioSupport::SupportTicket`, `trashed_at` null). A revised ticket counts once. `support_tickets.unassigned_open` counts open tickets (`status: "open"`) with no assignee. `support_tickets.oldest_open_age` is the age in seconds of the oldest open ticket, from the recording's `created_at` (`value` omitted when there are none). `support_tickets.opened` buckets that same open time. Results use the Metrics cache (default 5 minutes), so the age can lag by up to that TTL.

`group_by` (Metrics 0.3): `support_tickets.open` and `support_tickets.unassigned_open` accept `group_by=priority`; `support_tickets.opened` accepts `group_by=status` or `group_by=priority` with `from`/`to`/`interval`. Groups with fewer than 5 tickets fold into `other`, so groups plus `other` equal the total. `oldest_open_age`, `by_status` and `by_priority` take no `group_by`. There is no assignee grouping and no metric filters (Support has no ticket list endpoint whose filters they could mirror). The catalog lists `group_by`, `min_group_size`, `date_range`, `timezone` and `freshness` for each metric.

`support_tickets.avg_time_to_resolve` (unit `seconds`) is the mean of `resolved_at` minus the recording's `created_at` for tickets in the `resolved` status, bucketed by `resolved_at`, with `from`/`to`/`interval`. Later snapshots do not move the open time. A bucket with no resolutions is `null`, not 0. It accepts `group_by=priority` (the same queue grouping and 5-ticket fold as `open`). A reopened ticket clears `resolved_at` and counts again from its next resolution. There are no filters, as above.

`support_page_views.over_time` (unit `views`) counts Views raw logs for `RecordingStudioSupport::SupportPage` (one per signed-in or public page show) by `created_at`, with `from`/`to`/`interval`. Identifier, unit, and series shape are unchanged. Views are not de-duplicated by visitor, and there is no `group_by` or filter, so no viewer or page identity is exposed. Daily summaries (`RecordingStudioViews::DailyViewSummary`) are for Logs aggregation, not this public metric.

`GET support_pages?q=` on public uses `Pages.for_root` / `SupportPage.search`. There is no `GET support/search`. Instant UI is not used.

Do not add a Support `ApiController`. Domain writes stay `Pages` / `Sections`. Public anonymous browse stays `/help`.

Host sketch:

```ruby
gem "recording_studio_api", github: "bowerbird-app/RecordingStudio_api", tag: "v0.7.0"
```

```bash
bin/rails generate recording_studio_api:install
bin/rails generate recording_studio_api:migrations
bin/rails db:migrate
```

Enable `:api_access_point` (with `:accessible`) on roots that hold API keys. Dummy does this on `Workspace` and `AdminRoot`. Mount the engine. Provision two clients if you want the same split dummy uses: admin-root `:edit` for staff writes, workspace `:view` for read-only help.

Details: [docs/api.md](docs/api.md).

## Internationalization

The gem ships **English only** in `config/locales/en.yml`. Keys nest under `recording_studio.support.*`:

```ruby
t("recording_studio.support.help.search_placeholder")
t("recording_studio.support.contact.label")
t("recording_studio.support.messages.title")
```

Hosts own other languages. Copy `recording_studio.support.*` into `config/locales/<locale>.yml` and list that locale in `config.i18n.available_locales`. Do not add `RecordingStudio_Internationalization` as a dependency of this gem — it is optional on the host (the dummy uses it to switch English/French).

`public_help_title`, `public_help_subtitle`, `public_contact_label`, `public_section_subtitle`, and Search `placeholder:` still override the locale when the host sets custom text. A host that leaves the English default follows I18n.

Help article titles and bodies, section names, and other staff-written database content are data. This gem does not translate them. Staff Admin Support screens stay English.

## Dummy host

`test/dummy/` is a host that proves the gem. It is not the product.

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted file; do not generate a per-repo dummy key.

Dummy help pages, public and staff, use `recording_studio_layout`. A nil setting selects `recording_studio/default_layout`. Dummy still overrides that layout file so `<html>` gets `lang` and Flatpack copy data, the body calls `recording_studio_track_views`, and the top nav's right slot includes the language selector. Flatpack stylesheets load before Tailwind. Support screens and Admin Support screens keep that chrome only. Dummy does not inject Sign out or Root Switchable into the top nav (including dummy host pages, `/admin/support`, `/help`, and `/admin`). Access can stay on Admin. Do not put a login button there. Sign-in uses the Users gem (`recording_studio_user` `v0.21.0`): email at `/users/sign_in`, password at `/users/sign_in/password`, layout `recording_studio_user/auth` with `html data-theme="rounded"`. Help-page edit boots Flatpack's TipTap `TextArea` (`rich_text: true`, `preset: :content`, image upload). Dummy Stimulus registers `flat-pack--tiptap` on first paint. The dummy switches English and French with Recording Studio Internationalization. Article titles and seeded bodies stay in the language they were written.

| Field    | Value           |
|----------|-----------------|
| Email    | admin@admin.com |
| Password | Password        |

Dummy kit pins:

| Gem | Pin |
|-----|-----|
| Recording Studio | `v6.1.0` |
| Accessible | `v0.19.1` |
| Admin | `v2.7.0` |
| Attachable | `v0.15.0` |
| Messages | `v0.9.0` |
| Notifications | `v0.7.0` |
| Notifications Email | `v0.3.4` |
| Users | `v0.21.0` |
| Trashable | `v0.12.0` |
| Orderable | `v0.4.0` |
| Publishable | `v0.12.0` |
| Icons | `v0.1.1` |
| Moveable | `v3.4.3` |
| Search | `v0.6.0` |
| Root Switchable | `v0.10.0` |
| Cache | `v0.5.0` (dummy only; Users 0.21+ / Root Switchable 0.9+ floor) |
| API | `v0.7.0` (dummy only; not a Support gemspec dependency) |
| Internationalization | `v0.1.2` (dummy only; not a Support gemspec dependency) |
| FlatPack | `0.1.319` (`1fcbafe94f8eb118f0a22182f63f5110fcc97a56`) |
| ViewComponent | `4.19.0` |

```bash
cd test/dummy
bin/rails db:setup
bin/dev
```

Then open `/help` without signing in. Search the lists with `?q=`. Switch English/French with the compact language control in PageNav. Sign-in for Admin and staff forms is Users gem two-step login. Dummy uses Flatpack's built-in `rounded` theme on `<html data-theme="rounded">` for Users auth, public help, staff forms, and Admin. For `/admin`, pick **Admin** in the top workspace control first — Recording Studio Admin checks that the current root is the admin root. Edit, Move, and New live on the Admin tables. Forms and preview open under `/admin/support`. Old `/support` links redirect to `/admin`.

Seeds three sections: **Billing**, **Developers**, and **Getting started**, each with a Heroicons icon (`credit-card`, `code-bracket`, `rocket-launch`). Live articles inherit that section icon by default, include a short `description`, multi-section HTML bodies, and inline images where helpful (**How do I sign in?** and **How do I update payment details?**). **How do I change my password?** stays a draft under Getting started. Billing and Developers keep multiple/live pages for section lists.

## Cloud Agent boot

`.cursor/install.sh` runs at Cloud Agent Build. If `RAILS_MASTER_KEY` is set in the environment, it writes gitignored `test/dummy/config/master.key` so dummy credentials decrypt. It runs `.cursor/fetch-skills.sh` last. To load a new pack, rebuild with Draft off. See [Cursor skills in Cloud Agents](docs/cursor-skills.md).

## Engine internals

`docs/gem_template/` stays as engine-internal reference from the original addon template. This README is the product.
