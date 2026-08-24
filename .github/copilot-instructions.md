# Project Guidelines

## Architecture

- This repository is Recording Studio Support: staff write help pages, people help themselves.
- Preserve engine namespace isolation under `RecordingStudioSupport`.
- Treat `docs/gem_template/` as architectural reference material. The public README is the product. The dummy app is a host that proves the gem.
- Keep changes small and scoped. Support pages opt into Trashable, Moveable, and Publishable. Pictures live in the page body. Authenticated Support UI, Admin Support, and public read of live pages ship in this slice. Tickets and API do not. Public `/help` and staff `/support` search sections. Section show lists published pages.

## UI Conventions

- FlatPack is the default UI system. Authenticated Support screens and Admin widgets use Flatpack ViewComponents on Recording Studio's default layout.
- The approved UI reference is the live FlatPack demo app at https://flatpack.bowerbird.io/ when you need to inspect current shared components and patterns.
- When editing ERB views, prefer `render FlatPack::...` components over custom HTML when an equivalent component exists.

## Testing

- The standard root validation command is `bundle exec rake test:all` from the repository root.
- If a change affects dummy app boot, assets, or migrations, also validate the dummy app setup the same way CI does.
- Cover Support page declaration, root rejection, parent rejection, trash/restore, publish/indexable, inline body images, authenticated screens, public logged-out read, Accessible denial, and Admin Support enablement in Minitest. Folder and Page must not inherit those mixins just because the gems are installed.

## Repo Conventions

- Writes go through `record`, `revise`, `log_event!`, and the mixin public trash/move/publish APIs. Pictures upload through the body editor.
- Do not invent an ACL. Access uses `grant_access` / `authorized?` on recordings.
- Update docs when setup steps change. Keep the README as the product.
