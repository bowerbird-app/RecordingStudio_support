RecordingStudioSupport install complete.

Next steps:

1. Review config/initializers/recording_studio_support.rb. `pages_path` should match the authenticated mount path. `public_pages_path` is `/help`.
2. If you use environment-specific settings, create config/recording_studio_support.yml.
3. Install the engine migrations with `bin/rails generate recording_studio_support:migrations`.
4. Install mixin migrations with `bin/rails generate recording_studio_attachable:migrations`, `bin/rails generate recording_studio_trashable:migrations`, `bin/rails generate recording_studio_orderable:migrations`, and `bin/rails generate recording_studio_publishable:install` (or `recording_studio_publishable:migrations` if the engine is already mounted).
5. Apply the migrations with `bin/rails db:migrate`.
6. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
7. Authenticated Support screens are mounted at the configured path (default `/support`). Keep `RecordingStudio::UsesDefaultLayout` on those screens and authorize with Accessible on the workspace root (`:view` to read, `:edit` to write). Staff and public lists use Flatpack Search at full width (`?q=`, title and body ILIKE). Public search stays on indexable pages. Set help titles on `RecordingStudioSupport.configure` (`help_title`, `public_help_title`, `admin_help_title`) if you do not want the defaults. Keep Sign out and Root Switchable off Support screens. For the body editor, follow Flatpack's TextArea `rich_text` install: pin TipTap packages and register `controllers/flat_pack/tiptap_controller` as `flat-pack--tiptap`. Do not add Trix or Action Text. Keep `uploads: false` — images stay Attachable children.
8. Public help is logged-out read of indexable Support pages. Mount Publishable at `/` and point `/help` at `RecordingStudioSupport::PublicPagesController.action(:index)`. Keep public and staff help on `UsesDefaultLayout` / `recording_studio/default_layout` (set Publishable `public_layout` to that layout). Do not use `recording_studio_publishable/application`. Enable Publishable only on `SupportPage`. Support screens keep back/close only.
9. Enable the Admin Support section on your admin root:

```ruby
recording_studio_admin_sections do
  section :support
end
```

Mount Admin with `recording_studio_admin_for :admin, at: "/admin"` and grant access on the admin root (`bootstrap_owner_access!` for the first owner).
10. Register `"RecordingStudioSupport::SupportPage"` and `"RecordingStudioPublishable::Publishable"` next to your workspace type and keep `recording_studio_recordable(...)` on every configured type before running `RecordingStudio.validate_recordable_declarations!`.
