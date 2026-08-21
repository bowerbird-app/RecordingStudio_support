# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-08-21

Staff can write and read help pages, and open an Admin Support section. Still no public pages or Publishable.

### Added
- Authenticated Support screens at `/support`: list, show, new, and edit
- Admin Support section and help-pages screen with page count, latest pages, and reads
- Page reads stored as logs (`recording_studio_support_page_views`), not extra pages
- Dummy AdminRoot, `/admin` mount, workspace grants, two seeded help pages, and one image child
- Gemspec pin `recording_studio_admin ~> 2.0` (dummy GitHub tag `2.0.0`)
- Install generator mounts `/support` and enables `section :support` on an existing admin root

### Changed
- Dummy Tailwind also scans Admin and Support gem views so admin widgets and help screens get Flatpack utilities

### Upgrade notes
- Add `recording_studio_admin`, `~> 2.0` (dummy GitHub tag `2.0.0`)
- Run `bin/rails generate recording_studio_support:install` (or mount `RecordingStudioSupport::Engine` at `/support`)
- Run `bin/rails generate recording_studio_support:migrations` for the page-view log table
- Enable `section :support` on your admin root and mount `recording_studio_admin_for` at `/admin`
- Grant Accessible access on the workspace root for help screens and on the admin root for `/admin`
- Do not add Publishable, public pages, or `recording_studio_api` in this slice

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_support/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.5.0
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.2.0
[0.1.2]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.1.2
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_support/releases/tag/v0.1.0
