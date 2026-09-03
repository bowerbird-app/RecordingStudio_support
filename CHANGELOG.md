# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.2] - 2026-09-03

Dummy and host help screens use Flatpack's built-in rounded theme on `<html>`.

### Changed
- Dummy overrides `recording_studio/default_layout` so `<html data-theme="rounded">` is set. Core still puts `data-theme` on `<body>`; that is not enough for Flatpack component tokens (buttons stay the default purple/blue)
- Dummy layouts load Flatpack CSS in kit order: `flat_pack/variables`, `flat_pack/application`, `flat_pack/rich_text`, then Tailwind
- Login layout also loads `flat_pack/rich_text` and keeps the same html theme

### Upgrade notes
- Set `<html data-theme="rounded">` on the layout used by `/help`, `/support`, and `/admin`. Do not rely on core's body attribute
- Dummy's `test/dummy/app/views/layouts/recording_studio/default_layout.html.erb` is the host-side pattern. Copy that html attribute, not a custom theme
- Keep `UsesDefaultLayout`. Do not switch to `recording_studio_publishable/application` or a sidebar shell
- No schema or public API changes

## [0.7.1] - 2026-09-03

Cloud Agent Builds fetch Cursor skills at Build. Warm rebuilds skip the install steps when Ruby, bundle, and Postgres are already usable.

### Added
- `.cursor/environment.json`, `.cursor/install.sh`, `.cursor/fetch-skills.sh`, and `.cursor/start.sh`. Cloud Agent Builds load recording-studio-* skills and plugin `.mdc` rules
- Dummy `rails-server` and `tailwind-watch` terminals in `environment.json`

### Changed
- `.cursor/skills/` and `.cursor/rules/` are gitignored Build output. The pack is not vendored
- `.cursor/install.sh` skips apt, ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are already usable. A skippable provision failure does not fail the Build. `.cursor/fetch-skills.sh` always runs last

### Upgrade notes
- No host or schema changes. Rebuild the Cloud Agent environment with Draft off so Build loads the pack

## [0.7.0] - 2026-08-23

Help pages live in a section. Staff pick the section by moving the page.

### Added
- `RecordingStudioSupport::SupportSection` in this gem. Tree is host root → SupportSection → SupportPage
- Moveable on SupportPage through `.to`. Staff change section with `move_to!` (same root). No `section_id` column
- Orderable on SupportSection sorts its pages. Trashable on a section cascade-trashes its pages; empty sections trash cleanly
- Public `/help` lists sections. `/help/sections/:id` lists published pages only
- Staff `/support` lists sections. Staff and public section shows are the same reader list: published pages with a Published badge
- Admin Support hub has two family screens: Support pages and Support sections. Both are tables. The hub shows a page-count number widget
- Admin pages table keeps search, Published/Draft, section, Edit, Move, and New page
- Admin sections table has search, a Count column (`1` / `2`, every kept page in the section), Edit, and New section
- Body editor image upload at `POST /support/uploads` (returns `{ "url": "..." }`, same contract as Flatpack ContentEditor `upload_url`)
- Dummy seeds Billing, Developers, and Getting started. Existing pages sit under Getting started. Billing and Developers each have one live page so those lists are not empty
- Dummy GitHub pin `recording_studio_moveable` tag `3.0.0` and gemspec `~> 3.0`

### Changed
- SupportPage `allowed_parent_types` is SupportSection only, not Workspace. Break in place
- `Pages.create!` takes `parent_recording:` (the section). Writes still go through `record` / `revise` / `log_event!`
- Pictures live in the page body. SupportPage no longer includes Attachable or Orderable. No Pictures heading or image gallery
- Public show is a simple article: title, optional Updated line, and formatted body. No live/sign-in banners, no Edit/trash/Access
- Help Search placeholder is “Search support” on public and staff home and on section lists. Flatpack Search has no fill or height API, so the kit-default field is used
- Default Help subtitle is “Find an answer.” on public and staff home. Section show is the section name only
- Public and staff Help home search matches section names. Page search stays on a section show
- Public and staff section lists, and the page lists on section show, share one Flatpack List (`divider: true`) with a `chevron-right` trailing icon. The List sits in a Card body (Feature List kit pattern). No Read / Open buttons and no List border API
- Help home section rows show a Flatpack Badge with the published page count (`1` / `2`). Staff home uses the same published count as public
- Edit and New forms use two Flatpack Buttons (Save primary, Cancel secondary) in one row. Not a ButtonGroup and not a full-width Save
- Admin Support hub drops See every page, Latest pages, and the sections list widget

### Upgrade notes
- Register `"RecordingStudioSupport::SupportSection"` next to `"RecordingStudioSupport::SupportPage"`
- Run `bin/rails generate recording_studio_support:migrations` and `bin/rails db:migrate`
- Add `recording_studio_moveable`, `~> 3.0` (dummy GitHub tag `3.0.0`) and mount it at `/recording_studio_moveable`
- Enable Moveable only on Support pages: `include RecordingStudio::Capabilities::Moveable.to`
- Enable Orderable and Trashable on SupportSection. Do not enable Attachable or Publishable on the section
- Drop Attachable and Orderable from SupportPage. Put pictures in the body with the Flatpack rich-text editor (`preset: :content`, `uploads: { url: ... }`)
- Allow `img` (`src`, `alt`) in `Body.sanitize`
- Point `/help` and `/help/sections/:id` at the Support public controllers **before** mounting Publishable at `/`
- Create pages under a section. Move them with `recording.move_to!(new_parent: section, actor: current_user)`
- Open Admin tables at `/admin/screens/support_pages` and `/admin/screens/support_sections` (the old `help_pages` key is gone)
- Set `help_subtitle` and `public_help_subtitle` if you do not want “Find an answer.”
- Do not add a `section_id` column, a categories gem, a gallery on SupportPage, or a second Admin app

### Fixed
- Dummy host chrome gate also hides Sign out and Root Switchable on Moveable screens. Dummy does not copy the core default layout
- Dummy public, staff, and Admin help tests expect core layout `body[data-theme=rounded]`, not `html`

## [0.6.0] - 2026-08-21

### Changed
- Staff Edit and New live on the Admin help-pages table (every page, draft or live). Workspace `/support` and owner preview stay for reading and publish preview
- Edit and New still use the Support page controllers. Pages are found even when the current root is Admin, and staff with an admin-root grant can write. New pages still land under a workspace.
- Dummy Sign out and Root Switchable stay off Admin Support screens as well as Support screens. Access can stay on Admin
- Admin Support section keeps Latest pages and See every page. It drops the Help pages and Reads count cards
- Admin help-pages table adds search (title and body) and Published/Draft through the Admin table DSL. It hides the default Table data heading and row count

### Fixed
- RuboCop method-length on help configuration and modifier-if on the public help path helper
- Dummy `public_indexable` test uses unique titles so a seeded published sign-in page cannot double the result
- Dummy `test:dummy` prepares the test schema only (`RAILS_ENV=test`), so `db:prepare` does not seed the suite
- Admin table search test uses a unique title phrase so the seeded sign-in page body (“password”) cannot keep the row visible
- Dummy layout-head test expects the Support/Admin prefix gate, not `ApplicationController` only
- Dummy public and Admin help tests expect core layout `body[data-theme=rounded]`, not `html`

### Upgrade notes
- Open Edit and New from the Admin help-pages table. Take Edit off owner preview. Workspace `/support` stays for reading and publish preview
- Do not add a second mutation stack. The table still opens `/support/new` and `/support/:id/edit`
- Keep Sign out and Root Switchable off Support and Admin Support screens. Access can stay on Admin
- Drop Help pages and Reads count cards from the Admin Support hub. Keep Latest pages and See every page. Do not replace those cards with another total of the same fact
- Add search and Published/Draft on the Admin help-pages table with `table { filter ... }`. Hide the table heading and row count with the table DSL (`title` / `hide_count`). Do not add a custom search form or CSS hide

Logged-out people can read live help pages. Drafts stay hidden. Staff publish through Publishable.

### Added
- Publishable on `SupportPage` only through `.to` (`public_controller`, `public_action`, `public_layout`, `path`)
- Public help list at `/help` using `SupportPage.indexable`
- Public show through Publishable at `/help/:uuid/:slug`, with last updated from `publish_at`
- Staff draft preview on the authenticated show, plus a Publish button to Publishable's management screen
- Dummy GitHub pin `recording_studio_publishable` tag `v0.2.0` and gemspec `~> 0.2`
- Dummy seed publishes “How do I sign in?” and leaves “How do I change my password?” as a draft
- Host-configurable help titles and subtitles on `RecordingStudioSupport.configure`
- Public `/help` search of indexable pages (title + body ILIKE) with the same full-width Flatpack Search widget as staff

### Changed
- Dummy mounts Publishable at `/`
- Public and staff help use Recording Studio's default layout (`UsesDefaultLayout` / `recording_studio/default_layout`). Publishable `public_layout` points there. Do not use `recording_studio_publishable/application`.
- Support screens keep default-layout back/close only. Dummy Sign out and Root Switchable stay off those screens.
- Staff and public help lists use `FlatPack::Search::Component` at `max_width: :none`

### Upgrade notes
- Add `recording_studio_publishable`, `~> 0.2` (dummy GitHub tag `v0.2.0`)
- Run `bin/rails generate recording_studio_publishable:install` (or mount the engine at `/` and run its migrations)
- Register `"RecordingStudioPublishable::Publishable"` in `RecordingStudio.configure`
- Enable Publishable only on Support pages:

```ruby
include RecordingStudio::Capabilities::Publishable.to(
  public_controller: "recording_studio_support/public_pages",
  public_action: :show,
  public_layout: "recording_studio/default_layout",
  path: "/help/:uuid/:slug"
)
```

- Point `/help` at `RecordingStudioSupport::PublicPagesController.action(:index)`
- Use `SupportPage.indexable` / `indexable?` for public lists. Do not copy that logic
- Keep public and staff screens on `UsesDefaultLayout`. Point Publishable `public_layout` at `recording_studio/default_layout`. Do not use Publishable's own application layout. Do not enable Publishable on Folder or Page just because the gem is installed
- Set help copy on `RecordingStudioSupport.configure` (`help_title`, `help_subtitle`, `public_help_title`, `public_help_subtitle`, `admin_help_title`, `admin_help_subtitle`) if the defaults are not your words
- Keep Sign out and Root Switchable off Support screens. Core owns back/close
- Point public `/help?q=` at `Pages.public_indexable(query:)`. Do not add Elasticsearch or a new search gem
- Do not add tickets, email, messaging, Embeddable, Users, Billing, Webhooks, Notifications, or `recording_studio_api` in this slice

## [0.5.0] - 2026-08-21

Staff can write and read help pages, and open an Admin Support section. Still no public pages or Publishable.

### Added
- Authenticated Support screens at `/support`: list, show, new, and edit
- Help index search (`q`) with a full-width Flatpack Search and SQL ILIKE on title and body
- Configurable Help and Admin section titles on `RecordingStudioSupport.configure`
- Admin Support section and help-pages screen with page count, latest pages, and reads
- Page reads stored as logs (`recording_studio_support_page_views`), not extra pages
- Dummy AdminRoot, `/admin` mount, workspace grants, two seeded help pages, and one image child
- Gemspec pin `recording_studio_admin ~> 2.0` (dummy GitHub tag `2.0.0`)
- Install generator mounts `/support` and enables `section :support` on an existing admin root

### Changed
- Dummy Tailwind also scans Admin and Support gem views so admin widgets and help screens get Flatpack utilities
- Support screens keep core default-layout back/close only. Dummy Sign out and Root Switchable stay off those screens
- Dummy uses core `recording_studio/default_layout` (no host copy). Login keeps `html data-theme="rounded"`; core puts `rounded` on `<body>`
- Page body uses Flatpack `TextArea` `rich_text: true` (headings and lists). Images stay Attachable children. Show renders sanitized HTML.
- Dummy Stimulus registers Flatpack's nested TipTap controller (`flat-pack--tiptap`) so the body editor hydrates on first paint

### Upgrade notes
- Add `recording_studio_admin`, `~> 2.0` (dummy GitHub tag `2.0.0`)
- Run `bin/rails generate recording_studio_support:install` (or mount `RecordingStudioSupport::Engine` at `/support`)
- Run `bin/rails generate recording_studio_support:migrations` for the page-view log table
- Enable `section :support` on your admin root and mount `recording_studio_admin_for` at `/admin`
- Grant Accessible access on the workspace root for help screens and on the admin root for `/admin`
- Set Help copy on `RecordingStudioSupport.configure` (`pages_title`, `pages_subtitle`, `admin_section_title`, `admin_section_subtitle`)
- Keep Sign out and Root Switchable off Support screens. Dummy may still put them in `recording_studio/_default_layout_head.html.erb` for host pages, but not for `RecordingStudioSupport::ApplicationController`
- Hosts that want the body editor to boot should follow Flatpack's install pins for `flat_pack/tiptap` and register `controllers/flat_pack/tiptap_controller` as `flat-pack--tiptap` in Stimulus (lazy load is not enough on first paint). Dummy does this in `app/javascript/controllers/index.js`. This is Flatpack rich text, not Trix, Action Text, or a new editor gem
- Do not add Publishable, public pages, public search, or `recording_studio_api` in this slice

## [0.4.0] - 2026-08-21

Support pages can hold image children, move to trash, and sort those images. Folder and Page in a host still stay plain unless that host opts them in.

### Added
- Attachable, Trashable, and Orderable on `RecordingStudioSupport::SupportPage` through `.to` / `include_for`
- Gemspec pins `recording_studio_attachable ~> 0.4`, `recording_studio_trashable ~> 0.4`, and `recording_studio_orderable ~> 0.2`
- Dummy GitHub tags Attachable `0.4.0`, Trashable `0.4.0`, and Orderable `0.2.0`

### Upgrade notes
- Add the three mixin gems next to Support. GitHub hosting is not a reason to skip gemspec pins.
- Point dummy or host Gemfiles at Attachable `0.4.0`, Trashable `0.4.0`, and Orderable `0.2.0`.
- Run each mixin gem's migrations generator, plus Active Storage if the host does not have it yet.
- Keep `include RecordingStudio::Capabilities::Attachable.to(...)`, `Trashable.to`, and `Orderable.to(...)` on Support pages only. Do not copy that onto Folder or Page just because the gems are installed.
- Images are Attachable children. Do not add a support image type or put files in the page body.
- This slice still has no public pages, admin, Publishable, or API.

## [0.3.0] - 2026-08-21

First product release of Recording Studio Support. Staff write help pages under a workspace. People help themselves. No tickets, inbox, or chat.

### Added
- `RecordingStudioSupport::SupportPage` nested recordable under the host root (`Workspace` in dummy)
- Title and body on the page snapshot table `recording_studio_support_pages`
- Dummy seed for one support article
- Gemspec dependencies `recording_studio`, `~> 4.2` and `recording_studio_accessible`, `~> 0.6`

### Changed
- Renamed the engine from the addon template to `recording_studio_support`
- Dummy GitHub tags: Recording Studio `v4.2.0`, Accessible `v0.6.1`, Root Switchable `v0.5.0`, FlatPack `v0.1.133`

### Removed
- Leftover template identity in the public README and gemspec
- Dummy starter docs pages
- Template example capability mixin
- Engine sample home controller

### Upgrade notes
- Point host and dummy Gemfiles at Recording Studio `v4.2.0` and Accessible `v0.6.1`
- Declare `spec.add_dependency "recording_studio", "~> 4.2"` and `spec.add_dependency "recording_studio_accessible", "~> 0.6"`
- Register `"RecordingStudioSupport::SupportPage"` in `RecordingStudio.configure`
- Install engine migrations and keep writes on `record` / `revise` / `log_event!`
- Do not enable Publishable, Attachable, Trashable, Orderable, or API in this slice

## [0.2.0] - 2026-08-21

Addon starting point on Recording Studio 4.x, before this repo became Support.

### Added
- Gemspec dependency `recording_studio`, `~> 4.1`
- Dummy host wiring for Accessible (`enable_capability(:accessible, on: Workspace)`)
- `bin/rename_gem` leftover-identity rewrite/verification for README, homepage, and changelog URLs

### Changed
- Dummy GitHub tags: Recording Studio `v4.2.0`, Accessible `v0.6.0`, Root Switchable `v0.5.0`, FlatPack `v0.1.133`
- Dummy authenticated layout is Recording Studio's default layout plus FlatPack CSS/JS; Devise keeps its own sign-in layout
- Dummy app security pins: Rails `8.1.3.1`, `json` `2.21.2`, `mail` `2.9.1`, Brakeman `8.0.6`
- Require `RecordingStudio::Hooks` and `RecordingStudio::Services::BaseService` from core instead of shipping copies

### Removed
- Copied Hooks and BaseService files
- Product-shipped example service
- Custom `flat_pack_sidebar` authenticated shell

### Upgrade notes
- Point dummy or host Gemfiles at Recording Studio `v4.2.0` (not `recording_studio/v3.0.0`)
- Add `spec.add_dependency "recording_studio", "~> 4.1"` to addon gemspecs
- Include `RecordingStudio::UsesDefaultLayout` (or set `layout "recording_studio/default_layout"`) for authenticated screens
- Delete any copied Hooks or BaseService files and require the core classes
- Keep recordable declarations; they are required
- If Accessible is bundled, call `RecordingStudio.enable_capability(:accessible, on: Workspace)` (or your root type)

## [0.1.2] - 2026-07-21

### Changed
- Bumped the dummy app FlatPack dependency from `v0.1.33` to `v0.1.129`

## [0.1.1] - 2026-04-28

### Changed
- Bumped the dummy app FlatPack dependency from `0.1.2` to `0.1.33` and pinned it by tag in `test/dummy/Gemfile`

## [0.1.0] - 2025-12-04

### Added
- Initial release
- Rails mountable engine structure
- PostgreSQL with UUID primary keys support
- TailwindCSS v4 integration
- GitHub Codespaces devcontainer configuration
- Docker Compose setup with PostgreSQL and Redis
- Install generator for host applications
- Comprehensive README and documentation
- Basic test suite with Minitest

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_support/compare/v0.7.2...HEAD
[0.7.2]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.7.2
[0.7.1]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.7.1
[0.7.0]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.7.0
[0.6.0]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.6.0
[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.5.0
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.2.0
[0.1.2]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.1.2
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.1.0
