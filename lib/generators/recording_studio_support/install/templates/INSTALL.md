RecordingStudioSupport install complete.

Next steps:

1. Review config/initializers/recording_studio_support.rb. `pages_path` should match the staff mount path (`/admin/support` by default). `public_pages_path` is `/help`.
2. If you use environment-specific settings, create config/recording_studio_support.yml.
3. Install the engine migrations with `bin/rails generate recording_studio_support:migrations`.
4. Install mixin migrations with `bin/rails generate recording_studio_attachable:migrations`, `bin/rails generate recording_studio_trashable:migrations`, `bin/rails generate recording_studio_orderable:migrations`, and `bin/rails generate recording_studio_publishable:install` (or `recording_studio_publishable:migrations` if the engine is already mounted).
5. Apply the migrations with `bin/rails db:migrate`.
6. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
7. Staff Support forms and page preview are mounted at `/admin/support`. Mount that engine **before** `recording_studio_admin_for … at: "/admin"` so Admin does not swallow the path. Keep `RecordingStudio::UsesDefaultLayout` on those screens. Access is Recording Studio Admin: sign in, switch to the admin root, and grant Accessible on that admin root. Workspace `:edit` is not enough. Public `/help` lists sections. Section show lists published pages. Set help titles on `RecordingStudioSupport.configure` (`help_title`, `public_help_title`, `admin_help_title`) if you do not want the defaults. For the body editor, follow Flatpack's TextArea `rich_text` install: pin TipTap packages and register `controllers/flat_pack/tiptap_controller` as `flat-pack--tiptap`. Do not add Trix or Action Text. Pictures go in the body through the editor upload (`preset: :content` and `uploads: { url: ... }`, same contract as ContentEditor `upload_url`). Do not enable Attachable on SupportPage.
8. Public help is logged-out read of sections and their indexable Support pages. Point `/help` at `RecordingStudioSupport::PublicPagesController.action(:index)` and `/help/sections/:slug` at `PublicSectionsController` **before** mounting Publishable at `/`. Publishable also claims `/help/:uuid/:slug`, so a later `/help/sections/:slug` never wins. Section slugs live on `SupportSection` (no FriendlyId). Keep public help and staff forms on `UsesDefaultLayout` / `recording_studio/default_layout` (set Publishable `public_layout` to that layout). Set `<html data-theme="rounded">` on that layout so Flatpack's rounded theme applies. Do not use `recording_studio_publishable/application`. Enable Publishable only on `SupportPage`. Move pages between sections with Moveable (`move_to!`). Public `/help` and public section shows have no Close target (Back only). Public article shows Close to `/help`. Optional: set `public_contact_href` / `public_contact_label` and `public_section_subtitle` on `RecordingStudioSupport.configure` for the section contact slot and topic blurb. Old `/support` bookmarks redirect to `/admin`.
9. Enable the Admin Support section on your admin root:

```ruby
recording_studio_admin_sections do
  section :support
end
```

Mount Admin with `recording_studio_admin_for :admin, at: "/admin"` and grant access on the admin root (`bootstrap_owner_access!` for the first owner). Staff land in Admin Support tables. New, Edit, Move, preview, Publish, and uploads open under `/admin/support`.
10. Register `"RecordingStudioSupport::SupportSection"` and `"RecordingStudioSupport::SupportPage"` next to your workspace type, plus `"RecordingStudioPublishable::Publishable"`. Keep `recording_studio_recordable(...)` on every configured type before running `RecordingStudio.validate_recordable_declarations!`.
