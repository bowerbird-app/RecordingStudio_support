# Support JSON API

How a host, person, or AI agent talks to Support sections and pages over **Recording Studio API**. Public anonymous browse stays `/help`. This surface is authenticated.

Support does **not** gemspec-depend on `recording_studio_api`. Add that gem in the **host** (`v0.5.5` in dummy). If the constant is missing, Support boots with no JSON routes.

Do not add a Support `ApiController`. Writes go through `Pages` / `Sections`. Access is **Accessible** only.

## Install (host)

```ruby
gem "recording_studio_api", github: "bowerbird-app/RecordingStudio_api", tag: "v0.5.5"
```

```bash
bin/rails generate recording_studio_api:install
bin/rails generate recording_studio_api:migrations
bin/rails db:migrate
```

Mount the engine (dummy uses `/recording_studio_api`). Enable `:accessible` and `:api_access_point` on roots that hold API keys. Dummy does this on `Workspace` and `AdminRoot`.

Support registers `support_sections` and `support_pages` on boot when the API gem is loaded.

Live OpenAPI (Scalar) is optional and owned by the API gem. Generate it in the host if you want an explorer. This file is the Support contract even when Scalar is off.

## Auth

Bearer access token from OAuth `client_credentials`:

```http
POST /recording_studio_api/oauth/token
Content-Type: application/json

{ "grant_type": "client_credentials", "client_id": "…", "client_secret": "…" }
```

Then:

```http
Authorization: Bearer <access_token>
Accept: application/json
```

The API client’s `AccessGrant.actor` is the Accessible actor (person, machine, or agent). Same rules for all of them.

| Actor | `index` / `show` | `create` / `update` / trash / move |
| --- | --- | --- |
| Accessible `:edit` on **AdminRoot** | Yes (kept pages, including drafts) | Yes |
| Workspace `:view` (or stronger) **without** AdminRoot `:edit` | Yes (that workspace; drafts hidden) | No — `403` |
| Missing token | `401` | `401` |
| No Accessible grant | `403` / `401` | `403` / `401` |

## Endpoints

Mount prefix is the host’s API engine path. Dummy uses `/recording_studio_api`. Public API version is `v1`.

| Method | Path | Who | Notes |
| --- | --- | --- | --- |
| `GET` | `/recording_studio_api/api/v1/support_sections` | `:view` | List sections |
| `POST` | `/recording_studio_api/api/v1/support_sections` | AdminRoot `:edit` | Body: `title`, optional `icon`, `parent_id` (workspace recording) |
| `GET` | `/recording_studio_api/api/v1/support_sections/:id` | `:view` | One section |
| `PATCH` | `/recording_studio_api/api/v1/support_sections/:id` | AdminRoot `:edit` | `title`, `icon` |
| `DELETE` | `/recording_studio_api/api/v1/support_sections/:id` | AdminRoot `:edit` | Trash (`Sections.trash!`), not a hard delete |
| `GET` | `/recording_studio_api/api/v1/support_sections/:id/pages` | `:view` | Pages in that section. `?q=` searches articles |
| `POST` | `/recording_studio_api/api/v1/support_sections/:id/pages` | AdminRoot `:edit` | Parent from the URL. `title`, optional `body`, `description`, `icon` |
| `GET` | `/recording_studio_api/api/v1/support_pages` | `:view` | List pages. `?q=` searches articles |
| `POST` | `/recording_studio_api/api/v1/support_pages` | AdminRoot `:edit` | Body: `title`, optional `body`, `description`, `icon`, `parent_id` (section recording) |
| `GET` | `/recording_studio_api/api/v1/support_pages/:id` | `:view` | One page |
| `PATCH` | `/recording_studio_api/api/v1/support_pages/:id` | AdminRoot `:edit` | `title`, `description`, `icon`, `body` |
| `DELETE` | `/recording_studio_api/api/v1/support_pages/:id` | AdminRoot `:edit` | Trash (`Pages.trash!`) |
| `POST` | `/recording_studio_api/api/v1/support_pages/:id/actions/move` | AdminRoot `:edit` | Body: `parent_id` (destination section recording) |

Send writable fields at the JSON root. Do not wrap them in `attributes`.

Nested `GET`/`POST …/support_sections/:id/pages` also exist for show/update/destroy of a child when the API gem relationship endpoints are enabled (`index show create update destroy`). Collection `POST` on `support_pages` still needs `parent_id`.

Publishable `:publish` and Orderable reorder are not allowlisted yet.

## Fields

Sections serialize `title`, `slug`, `icon`. Writable: `title`, `icon`. Slug is Support-owned.

Pages serialize `title`, `description`, `icon`, `body`. Writable: those four. Body is sanitized (`Body.sanitize`).

Recording Studio API also returns recording ids, type, and relationship metadata on each record.

## Search

`GET …/support_pages?q=` and `GET …/support_sections/:id/pages?q=` use `Pages.apply_query` → `SupportPage.search` (trigram on title/body). Not Instant Search.

Empty `q` is a normal index. Staff/admin-root tokens still see drafts. Workspace-only tokens still hide drafts.

Search is rate limited **per API client** (default 30 requests per 60 seconds). Over the window: `429`, error code `rate_limit_exceeded`, header `Retry-After`. Tune `api_search_rate_limit_enabled`, `api_search_rate_limit_requests`, and `api_search_rate_limit_period_seconds` on `RecordingStudioSupport.configure`. Keep Recording Studio API read rate limits on in production as well.

## Examples

List live articles a workspace token can see:

```http
GET /recording_studio_api/api/v1/support_pages
Authorization: Bearer <workspace_token>
```

Search articles:

```http
GET /recording_studio_api/api/v1/support_pages?q=invoice
Authorization: Bearer <token>
```

Create a page (staff token):

```http
POST /recording_studio_api/api/v1/support_pages
Authorization: Bearer <staff_token>
Content-Type: application/json

{ "title": "How do I get a receipt?", "body": "<p>Open Billing.</p>", "parent_id": "<section_recording_id>" }
```

Design notes (handlers, intercept): [api-plan.md](api-plan.md).
