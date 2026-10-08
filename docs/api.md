# Support JSON API

How a host, person, or AI agent talks to Support sections and pages over **Recording Studio API**. Public anonymous browse stays `/help`. This surface is authenticated.

Support does **not** gemspec-depend on `recording_studio_api`. Add that gem in the **host** (`v0.6.4` in dummy). If the constant is missing, Support boots with no JSON routes.

Do not add a Support `ApiController`. Writes go through `Pages` / `Sections`. Access is **Accessible** only.

## Install (host)

```ruby
gem "recording_studio_api", github: "bowerbird-app/RecordingStudio_api", tag: "v0.6.4"
```

```bash
bin/rails generate recording_studio_api:install
bin/rails generate recording_studio_api:migrations
bin/rails db:migrate
```

Mount the engine (dummy uses `/recording_studio_api`). Enable `:accessible` and `:api_access_point` on roots that hold API keys. Dummy does this on `Workspace` and `AdminRoot`.

Name the Admin API `:operations` (`default_access :read_only`). Support registers **reads** on the public API and **writes** on `:operations`. Pass `operations:` explicitly on the operations registrations so the named-API read-only default does not apply.

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

| Actor | Public `index` / `show` | Operations `create` / `update` / trash / move |
| --- | --- | --- |
| Accessible `:edit` on **AdminRoot** (operations token) | Yes, with a public token that can view | Yes |
| Workspace `:view` (or stronger) **without** AdminRoot `:edit` | Yes (that workspace; drafts hidden) | No — `403` on operations; writes are not on public |
| Public token on operations | — | Rejected |
| Missing token | `401` | `401` |
| No Accessible grant | `403` / `401` | `403` / `401` |

## Public API (read-only)

Mount prefix is the host’s API engine path. Dummy uses `/recording_studio_api`. Public API version is `v1`.

| Method | Path | Who | Notes |
| --- | --- | --- | --- |
| `GET` | `/recording_studio_api/api/v1/support_sections` | `:view` | List sections |
| `GET` | `/recording_studio_api/api/v1/support_sections/:id` | `:view` | One section |
| `GET` | `/recording_studio_api/api/v1/support_sections/:id/pages` | `:view` | Pages in that section. `?q=` searches articles |
| `GET` | `/recording_studio_api/api/v1/support_sections/:id/pages/:id` | `:view` | One nested page |
| `GET` | `/recording_studio_api/api/v1/support_pages` | `:view` | List pages. `?q=` searches articles |
| `GET` | `/recording_studio_api/api/v1/support_pages/:id` | `:view` | One page |

Public `POST` / `PATCH` / `DELETE` and public page `move` are not registered (`404` / unsupported).

## Admin API (`api: :operations`, writes only)

| Method | Path | Who | Notes |
| --- | --- | --- | --- |
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

Operations has no `index` / `show`. Collection `POST` on `support_pages` still needs `parent_id`. Nested `POST …/support_sections/:id/pages` takes the parent from the URL.

Send writable fields at the JSON root. Do not wrap them in `attributes`.

Publishable `:publish` and Orderable reorder are not allowlisted yet.

## Fields

Sections serialize `title`, `slug`, `icon`. Writable: `title`, `icon`. Slug is Support-owned.

Pages serialize `title`, `description`, `icon`, `body`. Writable: those four. Body is sanitized (`Body.sanitize`).

Recording Studio API also returns recording ids, type, and relationship metadata on each record.

## Search

There is no `GET support/search`. Nested `GET …/support_sections/:id/pages?q=` and `GET …/support_pages?q=` search articles through `Pages.apply_query` → `SupportPage.search` (trigram). Same Access and per-client `SearchLimit` bucket. Empty `q` is a scoped live list and does not count against the bucket. Staff/admin-root readers still see draft pages. Workspace-only tokens still hide drafts and stay scoped to that client’s workspace root.

Search is rate limited **per API client** (default 30 requests per 60 seconds). Over the window: `429`, error code `rate_limit_exceeded`, header `Retry-After`. Tune `api_search_rate_limit_enabled`, `api_search_rate_limit_requests`, and `api_search_rate_limit_period_seconds` on `RecordingStudioSupport.configure`. Keep Recording Studio API read rate limits on in production as well.

## Examples

List live articles a workspace token can see:

```http
GET /recording_studio_api/api/v1/support_pages
Authorization: Bearer <workspace_token>
```

Nested page search:

```http
GET /recording_studio_api/api/v1/support_sections/:id/pages?q=invoice
Authorization: Bearer <token>
```

Create a page (operations editor token):

```http
POST /recording_studio_api/apis/operations/v1/support_pages
Authorization: Bearer <operations_token>
Content-Type: application/json

{ "title": "How do I get a receipt?", "body": "<p>Open Billing.</p>", "parent_id": "<section_recording_id>" }
```

Design notes (handlers, intercept): [api-plan.md](api-plan.md).
