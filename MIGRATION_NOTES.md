# Upgrade notes

## 0.6.0

Public help pages through Publishable 0.2.

- Recording Studio `~> 4.2` (dummy GitHub tag `v4.2.0`)
- Accessible `~> 0.6` (dummy GitHub tag `v0.6.1`)
- Admin `~> 2.0` (dummy GitHub tag `2.0.0`)
- Attachable `~> 0.4` (dummy GitHub tag `0.4.0`)
- Trashable `~> 0.4` (dummy GitHub tag `0.4.0`)
- Orderable `~> 0.2` (dummy GitHub tag `0.2.0`)
- Publishable `~> 0.2` (dummy GitHub tag `v0.2.0`)

### Host app

1. Add Publishable 0.2 next to Support. Follow the Publishable 0.2 README.
2. Run `bin/rails generate recording_studio_publishable:install` (mount at `/` and install migrations).
3. Register `"RecordingStudioPublishable::Publishable"` next to `"RecordingStudioSupport::SupportPage"`.
4. Enable Publishable only on Support pages with `.to`. Set `public_layout` to `recording_studio/default_layout` (Publishable's own default is a second shell).
5. Point `/help` at `RecordingStudioSupport::PublicPagesController.action(:index)`.
6. Use `SupportPage.indexable` for the public list. Staff still manage pages at `/support`.
7. Keep writes on `record` / `revise` and Publishable's Update helper. Do not insert Recording rows by hand.

Do not enable Publishable on Folder or Page just because the gem is installed. Do not use `recording_studio_publishable/application`. Do not invent a Support-only public shell.

### Verify

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

## 0.5.0

Authenticated help screens and an Admin Support section.

- Recording Studio `~> 4.2` (dummy GitHub tag `v4.2.0`)
- Accessible `~> 0.6` (dummy GitHub tag `v0.6.1`)
- Admin `~> 2.0` (dummy GitHub tag `2.0.0`)
- Attachable `~> 0.4` (dummy GitHub tag `0.4.0`)
- Trashable `~> 0.4` (dummy GitHub tag `0.4.0`)
- Orderable `~> 0.2` (dummy GitHub tag `0.2.0`)

### Host app

1. Add Admin 2.0 next to Support. Follow the Admin 2.0 README, not 1.x.
2. Mount authenticated screens: `mount RecordingStudioSupport::Engine, at: "/support"`.
3. Run `bin/rails generate recording_studio_support:migrations` for the page-view log table.
4. Create an admin root, enable `section :support`, and mount `recording_studio_admin_for :admin, at: "/admin"`.
5. Grant Accessible access on the workspace root (`:view` to read, `:edit` to write) and `bootstrap_owner_access!` on the admin root.
6. Keep writes on `record` / `revise` / `log_event!` and mixin helpers. Page reads go to `RecordingStudioSupport::PageView`, not a new page type.

Do not add Publishable, public pages, or an API in this slice.

### Verify

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

## 0.4.0

Support pages can attach images, go to trash, and sort those images.

- Recording Studio `~> 4.2` (dummy GitHub tag `v4.2.0`)
- Accessible `~> 0.6` (dummy GitHub tag `v0.6.1`)
- Attachable `~> 0.4` (dummy GitHub tag `0.4.0`)
- Trashable `~> 0.4` (dummy GitHub tag `0.4.0`)
- Orderable `~> 0.2` (dummy GitHub tag `0.2.0`)

### Host app

1. Add the three mixin gems with real gemspec constraints. GitHub hosting is not a reason to omit them.
2. Pin dummy or host Gemfiles at Attachable `0.4.0`, Trashable `0.4.0`, and Orderable `0.2.0`.
3. Run each mixin gem's migrations generator. Install Active Storage if the host does not already have it.
4. Keep enablement on Support pages only:

```ruby
include RecordingStudio::Capabilities::Attachable.to(
  allowed_content_types: ["image/*"],
  enabled_attachment_kinds: %i[image]
)
include RecordingStudio::Capabilities::Trashable.to
include RecordingStudio::Capabilities::Orderable.to(
  allows: ["RecordingStudioAttachable::Attachment"]
)
```

5. Attach images with `recording.import_attachment(...)`. Trash and restore with `recording_studio_trashable_trash!` / `recording_studio_trashable_restore!`. Reorder image siblings with `recording_studio_orderable_reorder!` or `recording_studio_orderable_move!`.

Do not add a support image type, Publishable, admin, or API in this slice.

### Verify

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

## 0.3.0

This repo is now Recording Studio Support, not the addon starting point.

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio `~> 4.2` (dummy GitHub tag `v4.2.0`)
- Accessible `~> 0.6` (dummy GitHub tag `v0.6.1`)
- Root Switchable dummy tag `v0.5.0` when the dummy host uses it
- FlatPack dummy tag `v0.1.133`

### Host app

1. Change the gem name from the old addon starting point to `recording_studio_support`.
2. Add `recording_studio`, `~> 4.2` and `recording_studio_accessible`, `~> 0.6`.
3. Register `"RecordingStudioSupport::SupportPage"` with your workspace type.
4. Run `bin/rails generate recording_studio_support:migrations` and `bin/rails db:migrate`.
5. Create pages with `root.record(RecordingStudioSupport::SupportPage)` and change them with `revise`.

Do not add Publishable, Attachable, Trashable, Orderable, or API in this slice.

### Verify

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```
