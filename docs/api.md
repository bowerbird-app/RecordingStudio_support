# Support JSON API

How a host, person, or AI agent talks to Support sections and pages over **Recording Studio API**. Public anonymous browse stays `/help`. This surface is authenticated.

Support does **not** gemspec-depend on `recording_studio_api`. Add that gem in the **host** (`v0.6.7` in dummy). If the constant is missing, Support boots with no JSON routes.

Do not add a Support `ApiController`. Writes go through `Pages` / `Sections`. Access is **Accessible** only.

## Install (host)

```ruby
gem "recording_studio_api", github: "bowerbird-app/RecordingStudio_api", tag: "v0.6.7"
```

```bash
bin/rails generate recording_studio_api:install
bin/rails generate recording_studio_api:migrations
bin/rails db:migrate
```

Mount the engine (dummy uses `/recording_studio_api`). Enable `:accessible` and `:api_access_point` on roots that hold API keys. Dummy does this on `Workspace` and `AdminRoot`.

Name the Admin API `:operations` (`default_access :read_only`). Support registers **page reads** on the public API and **section reads plus writes** on `:operations`. Handlers register with `register_resource_handler` (API `v0.6.7`) and call `Pages` / `Sections`. Pass `operations:` explicitly on the operations registrations so the named-API read-only default does not apply.

Live OpenAPI (Scalar) is optional and owned by the API gem. Generate it in the host if you want an explorer. This file is the Support contract even when Scalar is off.

## Auth

Bearer access token from OAuth `client_credentials`. Public clients use the public token path. Operations clients use the named-API token path:

```http
POST /recording_studio_api/oauth/token
Content-Type: application/json

{ "grant_type": "client_credentials", "client_id": "…", "client_secret": "…" }
```

```http
POST /recording_studio_api/apis/operations/oauth/token
Content-Type: application/json

{ "grant_type": "client_credentials", "client_id": "…", "client_secret": "…" }
```

Then:

```http
Authorization: Bearer <access_token>
Accept: application/json
```

The API client’s `AccessGrant.actor` is the Accessible actor (person, machine, or agent). Same rules for all of them. A public token is rejected on the operations API.

| Actor | Public page `index` / `show` | Operations section / nested-page `index` / `show` | Operations `create` / `update` / trash / move |
| --- | --- | --- | --- |
| Accessible `:edit` on **AdminRoot** (operations token) | Yes, with a public token that can view | Yes | Yes |
| Accessible `:view` on **AdminRoot** (operations token) | Yes, with a public token that can view | Yes | No — `403` |
| Workspace `:view` (or stronger) **without** AdminRoot | Yes (that workspace; drafts hidden) | No — `403` | No — `403`; writes are not on public |
| Public token on operations | — | Rejected | Rejected |
| Missing token | `401` | `401` | `401` |
| No Accessible grant | `403` / `401` | `403` / `401` | `403` / `401` |

## Public API (page reads only)

Mount prefix is the host’s API engine path. Dummy uses `/recording_studio_api`. Public API version is `v1`.

| Method | Path | Who | Notes |
| --- | --- | --- | --- |
| `GET` | `/recording_studio_api/api/v1/support_pages` | `:view` | List pages. `?q=` searches articles |
| `GET` | `/recording_studio_api/api/v1/support_pages/:id` | `:view` | One page |

Public `support_sections` list/show and nested section-pages are not registered (`404` / unsupported). Public `POST` / `PATCH` / `DELETE` and public page `move` are not registered.

## Admin API (`api: :operations`, section reads plus writes)

| Method | Path | Who | Notes |
| --- | --- | --- | --- |
| `GET` | `/recording_studio_api/apis/operations/v1/support_sections` | AdminRoot `:view` | List sections |
| `GET` | `/recording_studio_api/apis/operations/v1/support_sections/:id` | AdminRoot `:view` | One section |
| `GET` | `/recording_studio_api/apis/operations/v1/support_sections/:parent_id/pages` | AdminRoot `:view` | Pages in that section. `?q=` searches articles |
| `GET` | `/recording_studio_api/apis/operations/v1/support_sections/:parent_id/pages/:relationship_id` | AdminRoot `:view` | One nested page |
| `POST` | `/recording_studio_api/apis/operations/v1/support_sections` | AdminRoot `:edit` | Body: `title`, optional `icon`, `parent_id` (workspace recording) |
| `PATCH` | `/recording_studio_api/apis/operations/v1/support_sections/:id` | AdminRoot `:edit` | `title`, `icon` |
| `DELETE` | `/recording_studio_api/apis/operations/v1/support_sections/:id` | AdminRoot `:edit` | Trash (`Sections.trash!`), not a hard delete |
| `POST` | `/recording_studio_api/apis/operations/v1/support_sections/:id/pages` | AdminRoot `:edit` | Parent from the URL. `title`, optional `body`, `description`, `icon` |
| `PATCH` | `/recording_studio_api/apis/operations/v1/support_sections/:id/pages/:id` | AdminRoot `:edit` | Nested page revise |
| `DELETE` | `/recording_studio_api/apis/operations/v1/support_sections/:id/pages/:id` | AdminRoot `:edit` | Nested page trash |
| `POST` | `/recording_studio_api/apis/operations/v1/support_pages` | AdminRoot `:edit` | Body: `title`, optional `body`, `description`, `icon`, `parent_id` (section recording) |
| `PATCH` | `/recording_studio_api/apis/operations/v1/support_pages/:id` | AdminRoot `:edit` | `title`, `description`, `icon`, `body` |
| `DELETE` | `/recording_studio_api/apis/operations/v1/support_pages/:id` | AdminRoot `:edit` | Trash (`Pages.trash!`) |
| `POST` | `/recording_studio_api/apis/operations/v1/support_pages/:id/actions/move` | AdminRoot `:edit` | Body: `parent_id` (destination section recording) |

Operations has no top-level `GET support_pages`. Collection `POST` on `support_pages` still needs `parent_id`. Nested `…/support_sections/:parent_id/pages` takes the parent from the URL.

Send writable fields at the JSON root. Do not wrap them in `attributes`.

Publishable `:publish` and Orderable reorder are not allowlisted yet.

## Fields

Sections serialize `title`, `slug`, `icon`. Writable: `title`, `icon`. Slug is Support-owned.

Pages serialize `title`, `description`, `icon`, `body`. Writable: those four. Body is sanitized (`Body.sanitize`).

Recording Studio API also returns recording ids, type, and relationship metadata on each record.

## Search

There is no `GET support/search`. Public `GET …/support_pages?q=` uses `Pages.for_root` / `SupportPage.search`. Nested operations `GET …/support_sections/:parent_id/pages` lists pages in that section. Public workspace-only tokens hide drafts and stay scoped to that client’s workspace root. Operations AdminRoot `:view` readers see drafts.

## Examples

List live articles a workspace token can see:

```http
GET /recording_studio_api/api/v1/support_pages
Authorization: Bearer <workspace_token>
```

Nested page search (operations):

```http
GET /recording_studio_api/apis/operations/v1/support_sections/:parent_id/pages?q=invoice
Authorization: Bearer <operations_token>
```

Create a page (operations editor token):

```http
POST /recording_studio_api/apis/operations/v1/support_pages
Authorization: Bearer <operations_token>
Content-Type: application/json

{ "title": "How do I get a receipt?", "body": "<p>Open Billing.</p>", "parent_id": "<section_recording_id>" }
```

Design notes (handlers, intercept): [api-plan.md](api-plan.md).
