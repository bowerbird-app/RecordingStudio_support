# Upgrade notes

## Unreleased

## 0.8.2

Public article show header (Badge → Title → description → date), optional `description` field, PageNav Home.

### Host app

1. Run `bin/rails generate recording_studio_support:migrations` and `bin/rails db:migrate`. Adds optional `description` on `recording_studio_support_pages`.
2. Existing pages have `description` nil until an editor saves one (or you re-seed). Title stays required.
3. Public `/help/:uuid/:slug` no longer lists Related pages. Meta description uses `description` when set, otherwise the body excerpt.
4. Article PageNav uses secondary Home to `/help` (icon `home`, tooltip `"Home"`) instead of Close. Back still goes to the section (or `/help` with no section).
5. If the host overrides `recording_studio/default_layout`, pass Flatpack PageNav `secondary_anchor_href` (or `secondary_anchor_url` via Support's PageNavCompat) from `content_for(:page_nav_secondary_anchor_*)`. Until Recording Studio's layout helper lists those slots, set `content_for` in the view or retarget the primary Close control to Home.

### Verify

```bash
bundle exec rake test:all
```

## 0.8.1

Public help section show uses snippet cards and an optional host contact slot.

### Host app

1. No migrations or route changes.
2. Public `/help/sections/:slug` no longer lists pages with a Published badge. Cards link to the public article URL.
3. To show a contact footer on public section pages, set `public_contact_href` (and optionally `public_contact_label`) in `RecordingStudioSupport.configure`. Leave href blank to hide the slot.
4. Optional: set `public_section_subtitle` to a string or `->(section) { … }` for the topic blurb under the section title. Default is `Find answers in {title}.`
5. Staff `/support/sections/...` is unchanged.

### Verify

```bash
bundle exec rake test:all
```

## 0.7.4

Staff/admin process flows docs. Support authorize uses the page/section workspace root (or AdminRoot).

### Host app

1. No migrations or route changes.
2. Accessible grants stay on the **workspace root** (and AdminRoot for staff). Support no longer treats “`:edit` on the switched current root” as enough to mutate another workspace’s page or section by UUID. Unauthorized **edit** / **update** redirects to the show page. Other denied writes show a **No access** page (403).
3. Before adding Edit, trash, publish/unpublish, or restore UI, read `docs/process-flows.md`.

### Verify

```bash
bundle exec rake test:all
```

## 0.7.3

Public section URLs use a Support-owned slug. Staff Help hub can create pages and sections.

### Host app

1. Run `bin/rails generate recording_studio_support:migrations` and `bin/rails db:migrate`. Section titles backfill into `slug`.
2. Change the public section route to `/help/sections/:slug` (was `:id`). Keep it **before** mounting Publishable at `/`.
3. Staff `/support` and `/support/sections/:id` stay on recording UUIDs. No staff slug URLs. Those two screens are readable without signing in; write screens stay Accessible `:edit`.
4. Expect Accessible `:edit` users to see **New section** / **New page** on `/support`. Viewers and logged-out visitors do not.
5. Do not add FriendlyId. Page public URLs stay Publishable `/help/:uuid/:slug`.
6. Hosts can keep Devise `authenticate_user!` on ApplicationController. Support skips it for section index/show only.
7. Host layouts that load `flat_pack/rich_text` before Tailwind should declare `@layer theme, base, components, utilities` first so TipTap borders keep their width.
8. Staff show puts Publish, a Live/Draft status button, and icon-only trash in one PageTitle row. There is no live alert banner.
9. Public articles list Related published pages from the same section when any exist.
10. Help/support search overrides Flatpack Search tokens for a white field (`--color-white`) with a visible border.
11. Public articles set `<title>` from the page title and meta description from plain body text (tags stripped, entities decoded).

### Verify

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

## 0.7.0

Help pages live in a section. Staff pick the section by moving the page.

- Recording Studio `~> 4.2` (dummy GitHub tag `v4.2.0`)
- Accessible `~> 0.6` (dummy GitHub tag `v0.6.1`)
- Admin `~> 2.0` (dummy GitHub tag `2.0.0`)
- Attachable `~> 0.4` (dummy GitHub tag `0.4.0`)
- Trashable `~> 0.4` (dummy GitHub tag `0.4.0`)
- Orderable `~> 0.2` (dummy GitHub tag `0.2.0`)
- Publishable `~> 0.2` (dummy GitHub tag `v0.2.0`)
- Moveable `~> 3.0` (dummy GitHub tag `3.0.0`)

### Host app

1. Register `"RecordingStudioSupport::SupportSection"` next to `"RecordingStudioSupport::SupportPage"`.
2. Run `bin/rails generate recording_studio_support:migrations` and `bin/rails db:migrate`.
3. Add Moveable 3.0 and mount it at `/recording_studio_moveable`.
4. Enable Moveable only on Support pages with `.to`. Parent rules stay on `allowed_parent_types`.
5. Enable Orderable and Trashable on SupportSection. Do not enable Attachable or Publishable on the section.
6. Point `/help` and `/help/sections/:id` at the Support public controllers **before** mounting Publishable at `/`. Publishable also claims `/help/:uuid/:slug`.
7. Create pages under a section (`Pages.create!(parent_recording: section, ...)`). Move them with `move_to!`.
8. Keep one Admin Support section. Open **Support pages** and **Support sections** tables from that hub. Drop See every page and Latest pages. The page-count widget is the total of kept pages. The sections table Count column is the kept-page total for that section (`1` / `2`).
9. Drop Attachable and Orderable from SupportPage. Pictures go in the body through the Flatpack editor upload. Allow `img` in `Body.sanitize`.
10. Staff and public section lists show published pages only, with a Published badge. Staff Help home counts published pages.

Do not add a `section_id` column, nested sections, a gallery on SupportPage, or a second Admin app. Trashing a section cascade-trashes its pages (Trashable subtree). Empty sections trash cleanly.

### Verify

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

## 0.6.0

Staff edit help pages from the Admin help-pages table.

### Host app

1. Keep the existing Admin Support section. The child screen at `/admin/screens/help_pages` is the table of every page (draft and live).
2. Open Edit and New from that table. Those buttons still hit the Support page controllers (`/support/new`, `/support/:id/edit`). Do not add a second mutation stack. Writes still go through `record` / `revise`.
3. Take Edit off owner preview. Workspace `/support` stays for reading and publish preview.
4. Keep Sign out and Root Switchable off Support and Admin Support screens. Access can stay on Admin.
5. Staff with Accessible access on the admin root can edit from the table even when the current root is Admin. New pages still belong under a workspace.

### Verify

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

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
8. Set help titles on `RecordingStudioSupport.configure` if you do not want the defaults. Support screens keep default-layout back/close only.
9. Public `/help?q=` searches indexable pages with the same Flatpack Search widget as staff. Do not add Elasticsearch.

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
