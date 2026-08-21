RecordingStudioSupport install complete.

Next steps:

1. Review config/initializers/recording_studio_support.rb. `pages_path` should match the mount path.
2. If you use environment-specific settings, create config/recording_studio_support.yml.
3. Install the engine migrations with `bin/rails generate recording_studio_support:migrations`.
4. Install mixin migrations with `bin/rails generate recording_studio_attachable:migrations`, `bin/rails generate recording_studio_trashable:migrations`, and `bin/rails generate recording_studio_orderable:migrations`. Support pages use those mixins for images, trash/restore, and sibling order.
5. Apply the migrations with `bin/rails db:migrate`.
6. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
7. Authenticated Support screens are mounted at the configured path (default `/support`). Keep `RecordingStudio::UsesDefaultLayout` on those screens and authorize with Accessible on the workspace root (`:view` to read, `:edit` to write).
8. Enable the Admin Support section on your admin root:

```ruby
recording_studio_admin_sections do
  section :support
end
```

Mount Admin with `recording_studio_admin_for :admin, at: "/admin"` and grant access on the admin root (`bootstrap_owner_access!` for the first owner). Do not add public pages or Publishable yet.
9. Register `"RecordingStudioSupport::SupportPage"` next to your workspace type and keep `recording_studio_recordable(...)` on every configured type before running `RecordingStudio.validate_recordable_declarations!`.
