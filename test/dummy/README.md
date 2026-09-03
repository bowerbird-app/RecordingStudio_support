# Dummy host

This Rails app exists to prove Recording Studio Support in a real host. It is not the product.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded help sections and pages, one with an inline picture in the body
- Authenticated Support screens mounted at `/support`
- Public help at `/help` for logged-out visitors (default-layout chrome, Card-wrapped Flatpack List of sections with published page-count badges, then published pages)
- Admin Support section mounted at `/admin` on an admin root (switch to **Admin** in the top control first — Admin 2.0 gates staff screens on that root)
- Support pages opt into Trashable, Moveable, and Publishable. Dummy Folder and Page do not.
- Recording Studio default layout (`UsesDefaultLayout`) with dummy's `<html data-theme="rounded">` override so Flatpack's built-in rounded theme actually applies; back/close chrome on Support and Admin Support screens; Sign out and the workspace switcher on dummy host pages only; Flatpack CSS/JS, Turbo, and Tailwind source scanning
- Root Switchable in dummy host chrome, not on Support or Admin Support screens
- Mounted `RecordingStudio::Engine` route behavior inside a host app

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run the commands above from the dummy app directory, not the repository root.

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

## Layouts and assets

Authenticated pages include `RecordingStudio::UsesDefaultLayout` and render `recording_studio/default_layout`. That layout owns the back/close chrome and Flatpack flash alerts. Dummy overrides the layout file so `<html data-theme="rounded">` is set — Flatpack's built-in rounded theme, the same one the live kit uses. Core puts `data-theme` on `<body>` only, which does not recolor buttons and other component tokens. Do not invent a custom theme or a sidebar shell.

Public and staff help use the same default layout. Do not use Publishable's application layout or invent a Support-only public shell. Support and Admin Support screens are back/close only. Sign out and the workspace switcher stay off `/support`, `/help`, and `/admin`. Access can stay on Admin. Do not put a login button in that chrome.

Devise sign-in keeps `layouts/application` so the login card can stay centered. That layout still loads:

- `flat_pack/variables`
- `flat_pack/application`
- `flat_pack/rich_text`
- `tailwind`
- Importmap JS, including `@hotwired/turbo-rails`

The host injects Sign out and Root Switchable through `app/views/recording_studio/_default_layout_head.html.erb` for dummy host pages only, not Support or Admin Support screens. Do not put the switcher or a Sign out button in the home view body. Flatpack CSS loads from the layout in kit order (`flat_pack/variables`, `flat_pack/application`, `flat_pack/rich_text`, then Tailwind).

Help-page edit uses Flatpack `TextArea` with `rich_text: true`, `preset: :content`, and image upload. Importmap pins TipTap packages plus `controllers/flat_pack/tiptap_controller`. `app/javascript/application.js` imports `controllers`, and `controllers/index.js` registers `flat-pack--tiptap` so the toolbar and body HTML hydrate on first paint. Do not add Trix or Action Text. Pictures go in the body.

Login `layouts/application` and dummy's default-layout override both set `<html data-theme="rounded">`. Do not invent a custom theme.

Tailwind scans dummy views plus Flatpack, Recording Studio, Admin, Support, and Publishable gem files. On boot, Root Switchable's source linker plus dummy vendor links make a local `bin/rails tailwindcss:build` see those classes. Rebuild Tailwind after changing views.

## Useful Routes

- `/` - dummy host home page
- `/help` - public help sections (no sign-in)
- `/help/sections/:id` - published pages in a section (declare this before the Publishable mount)
- `/help/:uuid/:slug` - public help page through Publishable
- `/support` - authenticated help sections and publish preview (add `?q=` to search)
- `/admin` - Admin Support hub (pick **Admin** in the top control first)
- `/admin/screens/support_pages` - table of every help page with search, Published/Draft, and section; Edit, Move, and New page open from here
- `/admin/screens/support_sections` - table of every help section with a numeric page count; Edit and New section open from here
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Devise sign-in page
- `/up` - Rails health check

## Why This App Exists

Use this app to click through public help, staff help pages, and the Admin Support section. If a layout, route, asset source, or Recording Studio initializer change breaks here, the gem likely needs adjustment before reuse.

Seeds three sections under Studio Workspace: **Billing**, **Developers**, and **Getting started**. **How do I sign in?** is a live article with headings, a list, and an inline photograph (`public/how-to-sign-in.jpg`, Wikimedia Commons CC0 laptop keyboard). **How do I change my password?** stays a draft under Getting started, so the Admin sections table Count is `2` there and `1` on Billing and Developers. Public and staff Help still show published counts only. A few page reads are logged as support events.

Public and staff help use Recording Studio's shared default layout with dummy's html rounded theme. Devise sign-in keeps `layouts/application`. Both put `rounded` on `<html>`.
