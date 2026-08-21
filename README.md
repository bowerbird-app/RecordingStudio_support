# Recording Studio Support

Staff write help pages. People help themselves. No tickets, no inbox, no chat.

Support pages sit under your workspace as a flat list. Each page has a title and a body. A page can hold images, go to trash, and sort those images. This gem does not ship public pages, admin, search, or an API yet.

## Install

Add the gem next to Recording Studio 4.2, Accessible, and the mixin gems Support pages use. GitHub hosting is not a reason to skip the gemspec pins.

```ruby
# Gemfile
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.6.1"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "0.4.0"
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "0.4.0"
gem "recording_studio_orderable", github: "bowerbird-app/RecordingStudio_orderable", tag: "0.2.0"
gem "recording_studio_support", github: "bowerbird-app/RecordingStudio_support"
```

```ruby
# gemspec / host Gemfile constraints
gem "recording_studio", "~> 4.2"
gem "recording_studio_accessible", "~> 0.6"
gem "recording_studio_attachable", "~> 0.4"
gem "recording_studio_trashable", "~> 0.4"
gem "recording_studio_orderable", "~> 0.2"
```

Then:

```bash
bundle install
bin/rails generate recording_studio_support:install
bin/rails generate recording_studio_support:migrations
bin/rails generate recording_studio_attachable:migrations
bin/rails generate recording_studio_trashable:migrations
bin/rails generate recording_studio_orderable:migrations
bin/rails db:migrate
```

Install Active Storage if the host does not already have it. Images live as Attachable children, not in the page body.

## Support pages

Register the type next to your host root. Dummy uses `Workspace`. Attachable registers its own image child type.

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "RecordingStudioSupport::SupportPage"
  ]
  config.require_recordable_declarations = true
end
```

The page declares itself under that root and opts into the mixins. Installing the mixin gems does not turn this on for Folder or Page.

```ruby
recording_studio_recordable label: "Support page",
                            root: false,
                            allowed_parent_types: ["Workspace"]

include RecordingStudio::Capabilities::Attachable.to(
  allowed_content_types: ["image/*"],
  enabled_attachment_kinds: %i[image]
)
include RecordingStudio::Capabilities::Trashable.to
include RecordingStudio::Capabilities::Orderable.to(
  allows: ["RecordingStudioAttachable::Attachment"]
)
```

Create and change pages with public helpers. Do not insert Recording or Event rows by hand.

```ruby
root = RecordingStudio.root_recording_for(workspace)
page_recording = root.record(RecordingStudioSupport::SupportPage) do |page|
  page.title = "How do I sign in?"
  page.body = "Use the email and password you were given."
end

root.revise(page_recording) do |page|
  page.body = "Still stuck? Ask a teammate who already has access."
end

page_recording.import_attachment(
  io: image_file,
  filename: "sign-in.png",
  content_type: "image/png",
  actor: current_user
)

page_recording.recording_studio_orderable_reorder!(
  ordered_recording_ids: page_recording.recording_studio_orderable_children.map(&:id),
  actor: current_user
)

page_recording.recording_studio_trashable_trash!(actor: current_user)
page_recording.recording_studio_trashable_restore!(actor: current_user)

page_recording.log_event!(action: "viewed")
```

Access later uses `grant_access` / `authorized?` on recordings. This gem does not invent its own ACL.

## Dummy host

`test/dummy/` is a host that proves the gem. It is not the product.

| Field    | Value           |
|----------|-----------------|
| Email    | admin@admin.com |
| Password | Password        |

Dummy kit pins:

| Gem | Pin |
|-----|-----|
| Recording Studio | `v4.2.0` |
| Accessible | `v0.6.1` |
| Attachable | `0.4.0` |
| Trashable | `0.4.0` |
| Orderable | `0.2.0` |
| Root Switchable | `v0.5.0` |
| FlatPack | `v0.1.133` |

```bash
cd test/dummy
bin/rails db:setup
bin/dev
```

Seeds one signed-in article so later indexes are not empty. That seed does not attach images.

## Engine internals

`docs/gem_template/` stays as engine-internal reference from the original addon template. This README is the product.
