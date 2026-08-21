# Dummy host

This Rails app exists to prove Recording Studio Support in a real host. It is not the product.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded help pages, one with an image
- Authenticated Support screens mounted at `/support`
- Admin Support section mounted at `/admin` on an admin root (switch to **Admin** in the top control first — Admin 2.0 gates staff screens on that root)
- Support pages opt into Attachable, Trashable, and Orderable. Dummy Folder and Page do not.
- Recording Studio default layout (back/close chrome, Sign out next to the workspace switcher), Flatpack CSS/JS, Turbo, Tailwind source scanning, and Flatpack's built-in `rounded` theme on `<html>`
- Root Switchable in the default-layout chrome, not a host-only shell
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

Authenticated pages include `RecordingStudio::UsesDefaultLayout` and render `recording_studio/default_layout`. That layout owns the back/close chrome and Flatpack flash alerts.

Devise sign-in keeps `layouts/application` so the login card can stay centered. That layout still loads:

- `flat_pack/variables`
- `flat_pack/application`
- `tailwind`
- Importmap JS, including `@hotwired/turbo-rails`

The host injects `flat_pack/application`, Sign out, and the Root Switchable control through `app/views/recording_studio/_default_layout_head.html.erb`. Do not put the switcher or a Sign out button in the home view body.

Dummy copies Recording Studio's default layout so `<html data-theme="rounded">` uses Flatpack's built-in rounded theme. Login `layouts/application` already sets that attribute. Do not invent a custom theme.

Tailwind scans dummy views plus Flatpack, Recording Studio, Admin, and Support gem files. On boot, Root Switchable's source linker plus dummy vendor links make a local `bin/rails tailwindcss:build` see those classes. Rebuild Tailwind after changing views.

## Useful Routes

- `/` - dummy host home page
- `/support` - authenticated help-page list (add `?q=` to search)
- `/admin` - Admin Support section (pick **Admin** in the top control first)
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Devise sign-in page
- `/up` - Rails health check

## Why This App Exists

Use this app to click through help pages and the Admin Support section. If a layout, route, asset source, or Recording Studio initializer change breaks here, the gem likely needs adjustment before reuse.

Seeds two help pages under Studio Workspace, attaches a tiny image to one, and logs a few page reads so admin widgets are not empty.

Authenticated pages use Recording Studio's shared default layout. Devise sign-in keeps `layouts/application`. Both put Flatpack's built-in `rounded` theme on `<html>`.
