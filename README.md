# Recording Studio Support

Staff write help pages. People help themselves. No tickets, no inbox, no chat.

Support pages sit under your workspace as a flat list. Each page has a title and a body.

This gem does not ship public pages, admin, search, or an API yet. Hosts register the type and write through Recording Studio.

## Install

Add the gem next to Recording Studio 4.2 and Accessible. GitHub hosting is not a reason to skip the gemspec pins.

```ruby
# Gemfile
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.6.1"
gem "recording_studio_support", github: "bowerbird-app/RecordingStudio_support"
```

```ruby
# gemspec / host Gemfile constraints
gem "recording_studio", "~> 4.2"
gem "recording_studio_accessible", "~> 0.6"
```

Then:

```bash
bundle install
bin/rails generate recording_studio_support:install
bin/rails generate recording_studio_support:migrations
bin/rails db:migrate
```

## Support pages

Register the type next to your host root. Dummy uses `Workspace`.

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "RecordingStudioSupport::SupportPage"
  ]
  config.require_recordable_declarations = true
end
```

The page declares itself as a nested type under that root:

```ruby
recording_studio_recordable label: "Support page",
                            root: false,
                            allowed_parent_types: ["Workspace"]
```

Create and change pages with public helpers. Do not insert Recording or Event rows by hand.

```ruby
root = RecordingStudio.root_recording_for(workspace)
root.record(RecordingStudioSupport::SupportPage) do |page|
  page.title = "How do I sign in?"
  page.body = "Use the email and password you were given."
end

root.revise(page_recording) do |page|
  page.body = "Still stuck? Ask a teammate who already has access."
end

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
| Root Switchable | `v0.5.0` |
| FlatPack | `v0.1.133` |

```bash
cd test/dummy
bin/rails db:setup
bin/dev
```

Seeds one signed-in article so later indexes are not empty.

## Engine internals

`docs/gem_template/` stays as engine-internal reference from the original addon template. This README is the product.
