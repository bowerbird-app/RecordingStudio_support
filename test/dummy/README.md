# Dummy host

This Rails app exists to prove Recording Studio Support in a real host. It is not the product.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded help sections and pages, one with an image
- Authenticated Support screens mounted at `/support`
- Public help at `/help` for logged-out visitors (default-layout chrome, sections then published pages)
- Admin Support section mounted at `/admin` on an admin root (switch to **Admin** in the top control first — Admin 2.0 gates staff screens on that root)
- Support pages opt into Attachable, Trashable, Orderable, and Publishable. Dummy Folder and Page do not.
- Recording Studio default layout from core (back/close chrome on Support and Admin Support screens; dummy does not copy the layout file; Sign out and the workspace switcher on dummy host pages only), Flatpack CSS/JS, Turbo, Tailwind source scanning, and Flatpack's built-in `rounded` theme (login `html`, core layout `<body>`)
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

Authenticated pages include `RecordingStudio::UsesDefaultLayout` and render core's `recording_studio/default_layout`. That layout owns the back/close chrome and Flatpack flash alerts. Dummy does not copy the layout.

Public and staff help use the same default layout. Do not use Publishable's application layout or invent a Support-only public shell. Support and Admin Support screens are back/close only. Sign out and the workspace switcher stay off `/support`, `/help`, and `/admin`. Access can stay on Admin. Do not put a login button in that chrome.

Devise sign-in keeps `layouts/application` so the login card can stay centered. That layout still loads:

- `flat_pack/variables`
- `flat_pack/application`
- `tailwind`
- Importmap JS, including `@hotwired/turbo-rails`

The host injects `flat_pack/application` through `app/views/recording_studio/_default_layout_head.html.erb`. Sign out and Root Switchable sit in that partial for dummy host pages only, not Support or Admin Support screens. Do not put the switcher or a Sign out button in the home view body.

Help-page edit uses Flatpack `TextArea` with `rich_text: true`. Importmap pins TipTap packages plus `controllers/flat_pack/tiptap_controller`. `app/javascript/application.js` imports `controllers`, and `controllers/index.js` registers `flat-pack--tiptap` so the toolbar and body HTML hydrate on first paint. Do not add Trix or Action Text. Images stay Attachable children (`uploads: false`).

Login `layouts/application` sets `<html data-theme="rounded">`. Core default layout puts `rounded` on `<body>`. Do not invent a custom theme or copy the core layout into dummy.

Tailwind scans dummy views plus Flatpack, Recording Studio, Admin, Support, and Publishable gem files. On boot, Root Switchable's source linker plus dummy vendor links make a local `bin/rails tailwindcss:build` see those classes. Rebuild Tailwind after changing views.

## Useful Routes

- `/` - dummy host home page
- `/help` - public help sections (no sign-in)
- `/help/sections/:id` - published pages in a section
- `/help/:uuid/:slug` - public help page through Publishable
- `/support` - authenticated help sections and publish preview (add `?q=` to search)
- `/admin` - Admin Support hub (pick **Admin** in the top control first)
- `/admin/screens/help_pages` - table of every help page with search, Published/Draft, and section; Edit, Move, and New open from here
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Devise sign-in page
- `/up` - Rails health check

## Why This App Exists

Use this app to click through public help, staff help pages, and the Admin Support section. If a layout, route, asset source, or Recording Studio initializer change breaks here, the gem likely needs adjustment before reuse.

Seeds three sections under Studio Workspace: **Billing**, **Developers**, and **Getting started**. **How do I sign in?** is live and **How do I change my password?** stays a draft under Getting started. Billing and Developers each have one live page. One page has a tiny image. A few page reads are logged as support events.

Public and staff help use Recording Studio's shared default layout. Devise sign-in keeps `layouts/application`. Login puts `rounded` on `<html>`; core layout puts it on `<body>`.
