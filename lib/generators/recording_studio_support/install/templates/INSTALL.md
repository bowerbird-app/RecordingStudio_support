RecordingStudioSupport install complete.

Next steps:

1. Review config/initializers/recording_studio_support.rb and set any required options.
2. If you use environment-specific settings, create config/recording_studio_support.yml.
3. Install the engine migrations with `bin/rails generate recording_studio_support:migrations`.
4. Install mixin migrations with `bin/rails generate recording_studio_attachable:migrations`, `bin/rails generate recording_studio_trashable:migrations`, and `bin/rails generate recording_studio_orderable:migrations`. Support pages use those mixins for images, trash/restore, and sibling order.
5. Apply the migrations with `bin/rails db:migrate`.
6. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
7. Mount routes are added at the configured mount path. Adjust auth, layout, and current actor integration to match your host app.
8. Register `"RecordingStudioSupport::SupportPage"` next to your workspace type and keep `recording_studio_recordable(...)` on every configured type before running `RecordingStudio.validate_recordable_declarations!`.
