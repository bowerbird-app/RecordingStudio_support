# Support API plan

Installer and agent contract (endpoints, auth, fields, search): **[docs/api.md](api.md)**.

This page is the design for how Recording Studio Support exposes sections and pages on **Recording Studio API**. Access is **Accessible**. Admin is the staff UI, not a second ACL.

Public anonymous browse stays `/help`. The JSON API is authenticated (bearer client). Do not add a Support `ApiController`, `user.admin?`, or a Support permission table.

## Access

| Question | Answer |
| --- | --- |
| Who authorizes? | Recording Studio Accessible only |
| What is Admin? | Staff screens (`/admin`, `/admin/support`) gated by Accessible on the **admin root** |
| Write gate | `authorized?(actor:, recording: admin_root, role: :edit)` — same as `authorize_support!(:edit)` |
| Read gate | `authorized?(..., role: :view)` on the **workspace root that owns the section/page**, or on the **admin root** |
| Tree | Sections and pages still live under the workspace. Accessible is not enabled on `SupportPage` / `SupportSection` |
| Anonymous | `/help` only. No logged-out JSON |

| Actor | Public page `index` / `show` | Operations section / nested-page reads | Operations `create` / `update` / trash / move |
| --- | --- | --- | --- |
| Accessible `:edit` or `:admin` on **AdminRoot** | Yes with a public viewer token (all kept pages in the request’s workspace bucket, including drafts) | Yes with an operations token (AdminRoot `:view`) | Yes with an operations token |
| Accessible `:view` on **AdminRoot** | Yes with a public viewer token | Yes | No — `403` |
| Workspace `:view` (or stronger) **without** AdminRoot | Yes (that workspace’s help; drafts stay hidden unless product later says otherwise) | No — `403` | No — `403` |
| Public token on operations | — | Rejected | Rejected |
| No Accessible grant | `403` / `401` | `403` / `401` | `403` / `401` |

The API client’s `AccessGrant.actor` is the actor. Same check for a person, machine client, or agent.

Stock API resource create/update authorize `:edit` on the **parent recording** (workspace/section). That would let a workspace editor write help the UI forbids. Support write handlers must **not** use that default. They authorize the **admin root**, then call Support domain writes. Intercept wrappers apply to the same ResourceOperations / relationship / member-action classes used by the operations API.

## Host vs gem

Support does **not** gemspec-depend on `recording_studio_api` (same pattern as Moveable). If the constant is missing, Support boots with no JSON routes.

The **host** adds the API gem, runs its install/migrations, mounts the engine, names `:operations`, enables `:accessible` and `:api_access_point` on roots that hold API keys, and provisions clients. Dummy wires this (`recording_studio_api` `v0.6.4`).

## Registration

Register both types when `RecordingStudioApi` is defined (`to_prepare`). Resource names are `support_sections` and `support_pages`. Public is page reads only. Operations is section reads plus writes — pass `operations:` so `:read_only` does not apply. Do not register `GET support/search`. Do not register `support_sections` on public.

```ruby
RecordingStudioApi.register_recordable_type_api(
  "RecordingStudioSupport::SupportSection",
  api: :operations,
  serializer: ->(section, **) {
    { title: section.title, slug: section.slug, icon: section.icon }
  },
  output_keys: %i[title slug icon],
  writable_attributes: %i[title icon],
  operations: %i[index show create update destroy],
  relationships: {
    pages: {
      source: :children,
      child_type: "RecordingStudioSupport::SupportPage",
      many: true,
      include: :request,
      serializer: ->(page, **) {
        {
          title: page.title,
          description: page.description,
          icon: page.icon,
          body: page.body
        }
      },
      output_keys: %i[title description icon body],
      limit: 50,
      endpoints: %i[index show create update destroy]
    }
  }
)

RecordingStudioApi.register_recordable_type_api(
  "RecordingStudioSupport::SupportPage",
  api: :public,
  serializer: ->(page, **) {
    {
      title: page.title,
      description: page.description,
      icon: page.icon,
      body: page.body
    }
  },
  output_keys: %i[title description icon body],
  writable_attributes: %i[title description icon body],
  operations: %i[index show]
)

RecordingStudioApi.register_recordable_type_api(
  "RecordingStudioSupport::SupportPage",
  api: :operations,
  serializer: ->(page, **) {
    {
      title: page.title,
      description: page.description,
      icon: page.icon,
      body: page.body
    }
  },
  output_keys: %i[title description icon body],
  writable_attributes: %i[title description icon body],
  operations: %i[create update destroy],
  capability_actions: %i[move]
)
```

Do not use `register_endpoint` for these. They are tree recordables. There is no general Support search endpoint.

## Routes

Public API v1:

```text
GET    /recording_studio_api/api/v1/support_pages
GET    /recording_studio_api/api/v1/support_pages/:id
```

Operations API v1:

```text
GET    /recording_studio_api/apis/operations/v1/support_sections
GET    /recording_studio_api/apis/operations/v1/support_sections/:id
GET    /recording_studio_api/apis/operations/v1/support_sections/:parent_id/pages
GET    /recording_studio_api/apis/operations/v1/support_sections/:parent_id/pages/:relationship_id

POST   /recording_studio_api/apis/operations/v1/support_sections
PATCH  /recording_studio_api/apis/operations/v1/support_sections/:id
DELETE /recording_studio_api/apis/operations/v1/support_sections/:id

POST   /recording_studio_api/apis/operations/v1/support_sections/:id/pages
PATCH  /recording_studio_api/apis/operations/v1/support_sections/:id/pages/:id
DELETE /recording_studio_api/apis/operations/v1/support_sections/:id/pages/:id

POST   /recording_studio_api/apis/operations/v1/support_pages
PATCH  /recording_studio_api/apis/operations/v1/support_pages/:id
DELETE /recording_studio_api/apis/operations/v1/support_pages/:id
POST   /recording_studio_api/apis/operations/v1/support_pages/:id/actions/move
```

`POST` create at the collection needs `parent_id` (workspace recording for a section; section recording for a page). Nested `…/support_sections/:id/pages` takes the parent from the URL.

`DELETE` means Support trash (`Pages.trash!` / `Sections.trash!`), not a hard delete.

Optional later: Publishable `:publish` on pages, Orderable reorder on a section. Only if those mixins register an API action and Support allowlists it.

## Handlers

Stock Index/Show stay on public pages if they honor `:view` on workspace **or** admin root. Operations section and nested-page reads require AdminRoot `:view`. Filter:

- AdminRoot `:edit` (or `:view` if we mirror staff preview) — include drafts
- Workspace `:view` without admin write — live/`indexable` pages only, matching public `/help`

`GET support_pages?q=` stays on the public API. Nested `GET support_sections/:parent_id/pages?q=` is operations-only. Rate limit searches per API client (default 30/minute). Empty `q` is a scoped live list and does not count against that bucket.

Replace Create / Update / Destroy with Support handlers (same intercept on public and operations):

1. Resolve admin root the same way staff UI does (`RecordingStudioAdmin` access recording resolver). Fail closed if missing.
2. `access_grant.authorize!(recording: admin_root, role: :edit)` — or `RecordingStudioAccessible.authorized?` with the grant actor.
3. Call `Sections.create!` / `revise!` / `trash!` or `Pages.create!` / `revise!` / `trash!` with `actor: access_grant.actor`.
4. Sanitize body through `Body.sanitize`. Slug stays Support-owned (`SupportSection.slug_for`).
5. Never `SupportPage.create!` plus `Recording.create!`.

Move stays Moveable’s registered `:move` action on operations. After authorize, Support still requires AdminRoot `:edit` (wrap or extra check) so a workspace `:edit` token cannot move pages.

## Dummy

Dummy adds `recording_studio_api` (host Gemfile only), installs, mounts, names `:operations`, and enables `api_access_point` on `Workspace` and `AdminRoot`. Seed:

1. Public workspace-only API client (index/show)
2. Operations AdminRoot `:edit` client (writes)
3. Operations AdminRoot `:view` client (writes denied)

## Tests

Gem suite:

- Registration is a no-op without `RecordingStudioApi`
- Public registration is page index/show only; operations registration is section index/show plus writes and nested page reads, plus page move
- Writes go through `Pages` / `Sections` (new recordable row on revise)
- `GET support/search` files are gone; public list `?q=` remains; nested `?q=` is operations-only

Dummy suite:

- Public writes and public move: not-found / unsupported
- Operations editor token: CRUD on section and page, including nested create and move
- Public token on operations: rejected
- Operations viewer: writes `403`
- Public page index/show and list `?q=` still work
- Public section routes are not found / unsupported
- Operations editor and viewer can read sections and nested pages; viewer still cannot write
- `GET support/search` is gone (`404`)

## Out of scope

- Tickets, inbox, chat
- Accessible on each page/section (stop and extend Accessible if we need per-article authors)
- Changing public `/help`
