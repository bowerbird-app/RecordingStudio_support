# Project Guidelines

## Architecture

- This repository is Recording Studio Support: staff write help pages, people help themselves.
- Preserve engine namespace isolation under `RecordingStudioSupport`.
- Treat `docs/gem_template/` as architectural reference material. The public README is the product. The dummy app is a host that proves the gem.
- Keep changes small and scoped. Support pages opt into Attachable, Trashable, and Orderable. Authenticated Support UI and Admin Support ship in this slice. Public pages, Publishable, search, and API do not.

## UI Conventions

- FlatPack is the default UI system. Authenticated Support screens and Admin widgets use Flatpack ViewComponents on Recording Studio's default layout.
- The approved UI reference is the live FlatPack demo app at https://flatpack.bowerbird.io/ when you need to inspect current shared components and patterns.
- When editing ERB views, prefer `render FlatPack::...` components over custom HTML when an equivalent component exists.

## Testing

- The standard root validation command is `bundle exec rake test:all` from the repository root.
- If a change affects dummy app boot, assets, or migrations, also validate the dummy app setup the same way CI does.
- Cover Support page declaration, root rejection, parent rejection, image attach, trash/restore, sibling reorder, authenticated screens, Accessible denial, and Admin Support enablement in Minitest. Folder and Page must not inherit those mixins just because the gems are installed.

## Repo Conventions

- Writes go through `record`, `revise`, `log_event!`, and the mixin public attach/trash/order APIs.
- Do not invent an ACL. Access uses `grant_access` / `authorized?` on recordings.
- Update docs when setup steps change. Keep the README as the product.
