# Dummy host

This Rails app exists to prove Recording Studio Support in a real host. It is not the product.

## What It Covers

- Recording Studio Users auth (Devise actor + People/Profile) with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded help sections and pages, one with an inline picture in the body
- Support screens mounted at `/admin/support` (Admin-gated forms and preview). Old `/support` redirects to `/admin`
- Public help at `/help` for logged-out visitors (default-layout chrome, interactive Flatpack Cards with optional Heroicons icon + **N article(s)** line, then published pages)
- Admin Support section mounted at `/admin` on an admin root (switch to **Admin** in the top control first — Admin 2.0 gates staff screens on that root)
- Recording Studio API mounted at `/recording_studio_api` with `api_access_point` on `Workspace` and `AdminRoot`, plus a named `:operations` API. Seeds a public workspace-only client (`:view`) and operations clients on **AdminRoot** (help records stay under Workspace)
- Support pages opt into Trashable, Moveable, and Publishable. Dummy Folder and Page do not.
- Recording Studio default layout via `recording_studio_layout` (nil falls through to `recording_studio/default_layout`). Dummy's layout override sets `<html>` `data-theme="rounded"`, `lang`, and kit copy data. Back and close use `flat_pack_page_nav`. A compact language selector sits in the top nav's right slot (English/French via Recording Studio Internationalization). No Sign out or workspace switcher in that nav. Flatpack CSS loads before Tailwind. Users auth also puts `rounded` on `<html>`.
- Root Switchable stays installed for workspace switching via its own routes, not PageNav chrome
- Mounted `RecordingStudio::Engine` route behavior inside a host app

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run the commands above from the dummy app directory, not the repository root.

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted file; do not generate a per-repo dummy key.

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

Sign-in is two steps from the Users gem (not a host Devise view):

1. `/users/sign_in` — email only, **Continue with email**
2. `/users/sign_in/password` — password

Auth uses `layouts/recording_studio_user/auth` with `html data-theme="rounded"`. Dummy does not copy those templates.

## Layouts and assets

Authenticated pages call `recording_studio_layout`. A nil setting renders `recording_studio/default_layout`. That layout owns back/close chrome and Flatpack flash alerts. Dummy overrides the layout file so `<html>` gets `data-theme="rounded"`, `lang`, and Flatpack copy data. Core `v6.1.0` already sets the theme on `<html>`. The override adds the language selector, view tracking, and the content-editor sheet. Do not invent a custom theme or a sidebar shell. A compact `recording_studio_language_selector` sits in the top nav right slot (English/French).

Public and staff help use the same default layout. Do not use Publishable's application layout or invent a Support-only public shell. Support and Admin Support screens are back/close only. Sign out and the workspace switcher stay off PageNav, including dummy host pages, `/admin/support`, `/help`, and `/admin`. Access can stay on Admin. Do not put a login button in that chrome. Switch language from PageNav; article titles stay in the language they were written.

Users gem sign-in and sign-up use `layouts/recording_studio_user/auth`. That layout loads Tailwind, Flatpack stylesheets (`flat_pack/variables`, `flat_pack/application`, `flat_pack/rich_text`), and Importmap JS (`@hotwired/turbo-rails`). Host `layouts/application` is not in the auth stack.

The host `recording_studio/_default_layout_head.html.erb` does not inject Sign out or Root Switchable. Do not put the switcher or a Sign out button in the home view body. Flatpack CSS loads from the layout in kit order (`flat_pack/variables`, `flat_pack/application`, `flat_pack/rich_text`, `flat_pack/content_editor`, then Tailwind). Declare `@layer theme, base, components, utilities` before those sheets so TipTap editor borders are not cleared by Tailwind preflight. Dummy Tailwind also re-asserts `.fp-card-hover-strong:hover` in `@layer utilities` so interactive Card strong hover is not blocked by Tailwind’s border utilities.

Help-page edit uses Flatpack `TextArea` with `rich_text: true`, `preset: :content`, and image upload. Importmap pins TipTap packages plus `controllers/flat_pack/tiptap_controller`. `app/javascript/application.js` imports `controllers`, and `controllers/index.js` registers `flat-pack--tiptap` so the toolbar and body HTML hydrate on first paint. Do not add Trix or Action Text. Pictures go in the body.

Users auth and dummy's default-layout override both set `<html data-theme="rounded">`. Do not invent a custom theme.

Tailwind scans dummy views plus Flatpack, Recording Studio, Users, Admin, Support, and Publishable gem files. On boot, Root Switchable's source linker plus dummy vendor links make a local `bin/rails tailwindcss:build` see those classes. Rebuild Tailwind after changing views.

OTP is off (`otp_enabled = false`). OmniAuth Continue-with buttons appear only when Rails credentials under `omniauth:` hold a provider. No ENV secret fallbacks.

## Useful Routes

- `/` - dummy host home page
- `/help` - public help sections (no sign-in). Switch English/French from the PageNav language selector
- `/help/messages` - signed-in messages desk
- `/help/sections/:slug` - published pages in a section (declare this before the Publishable mount; UUID bookmarks redirect). Typing filters articles in a Turbo Frame via Instant Search (`/help/sections/:slug/instant_search`)
- `/recording_studio_search/instant_search` - Search Instant engine (live `SupportPage` only)
- `/help/:uuid/:slug` - public help page through Publishable
- `/admin` - Admin Support hub (pick **Admin** in the top control first). Old `/support` redirects here
- `/admin/screens/support_pages` - table of every help page with search, Published/Draft, and section; Edit, Move, and New page open from here
- `/admin/screens/support_sections` - table of every help section with a numeric page count; Edit and New section open from here
- `/admin/support/new` - New page form (Admin Accessible)
- `/admin/support/:id` - staff preview, publish dropdown, and trash
- `/admin/support/:id/edit` - Edit page form
- `/recording_studio_api/oauth/token` - OAuth `client_credentials` for a public API bearer token
- `/recording_studio_api/apis/operations/oauth/token` - OAuth `client_credentials` for an operations API bearer token
- `/recording_studio_api/api/v1/support_pages` - public JSON pages (`GET` list / show). `?q=` searches articles
- `/recording_studio_api/apis/operations/v1/support_sections` - operations section reads (`GET`) and writes (`POST` / `PATCH` / `DELETE`)
- `/recording_studio_api/apis/operations/v1/support_sections/:parent_id/pages` - operations nested pages (`GET` list / show, including `?q=`) plus writes
- `/recording_studio_api/apis/operations/v1/support_pages` - operations writes and `POST …/actions/move`
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Users gem email-first sign-in
- `/users/sign_in/password` - Users gem password step
- `/recording_studio_users/profile` - Users gem profile
- `/up` - Rails health check

## Why This App Exists

Use this app to click through public help, Admin Support, and staff forms under `/admin/support`. Bearer clients can hit `/recording_studio_api/api/v1/support_pages` with the same Accessible rules as staff. If a layout, route, asset source, or Recording Studio initializer change breaks here, the gem likely needs adjustment before reuse.

Seeds three sections under Studio Workspace: **Billing**, **Developers**, and **Getting started**. Live pages carry a short `description` summary. **How do I sign in?** is a live article with headings, a list, and an inline photograph (`public/how-to-sign-in.jpg`, Wikimedia Commons CC0 laptop keyboard). **How do I update payment details?** is a longer Billing article with ordered card-field steps, tip blockquote (same text color as the article), and a parked credit-card form JPEG at `public/how-to-update-payment.jpg` (seed serves that file; it does not fetch the web). **How do I change my password?** stays a draft under Getting started. Billing also has **Where is my invoice?**; Developers has one live page. Admin sections table Count is `2` on Getting started and Billing, and `1` on Developers. Public Help lists show published counts/pages only; staff section show under `/admin/support/sections/:id` lists drafts too. A few page reads are logged as support events.

Public and staff help use Recording Studio's shared default layout with dummy's html rounded theme. Sign-in uses the Users gem auth layout. Both put `rounded` on `<html>`.
