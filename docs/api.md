# Support JSON API

How a host, person, or AI agent talks to Support sections and pages over **Recording Studio API**. Public anonymous browse stays `/help`. This surface is authenticated.

Support does **not** gemspec-depend on `recording_studio_api`. Add that gem in the **host** (dummy pins `v0.23.1`). If the constant is missing, Support boots with no JSON routes.

Support **does** depend on `recording_studio_metrics` and registers site-wide Support metrics. The host calls `RecordingStudioMetrics::Api.register!(api: :operations)` once.

Do not add a Support `ApiController`. Writes go through `Pages` / `Sections`. Access is **Accessible** only.

## Install (host)

```ruby
gem "recording_studio_api", github: "bowerbird-app/RecordingStudio_api", tag: "v0.23.1"
```

```bash
bin/rails generate recording_studio_api:install
bin/rails generate recording_studio_api:migrations
bin/rails db:migrate
```

Mount the engine (dummy uses `/recording_studio_api`). Enable `:accessible` and `:api_access_point` on roots that hold API keys. Dummy does this on `Workspace` and `AdminRoot`.

Name the Admin API `:operations` (`default_access :read_only`). Support registers **page reads** on the public API and **SupportCenter reads/create plus section reads and writes** on `:operations`. Tickets follow the same public-reads vs operations-writes split: public `index` / `show` / `open`, operations `index` / `show` / `update`. Page writes on operations include `create` / `update` / `destroy` in `operations:` so MCP `describe` matches the handlers. Handlers register with `register_resource_handler` and call `Pages` / `Sections` / `Tickets`. From API `0.6.9`, registered handlers receive raw ids (`id`, `parent_id`, `relationship_id`) and look up kept Support records themselves. Pass `operations:` explicitly on the operations registrations so the named-API read-only default does not apply. List handlers read `PaginateResourceCollection` `Page` or a Hash. `CenterType.register!` owns SupportCenter type registration, including its OpenAPI tag. `TicketType.register!` owns SupportTicket.

Provision operations clients on **AdminRoot** (featured_in). Support handlers find Workspace help by id and authorize AdminRoot `:view` / `:edit`. Move accepts `parent_id`, `destination_id`, or `new_parent_id`. Section create ignores trashed parents.

Live OpenAPI (Scalar) is optional and owned by the API gem. Generate it in the host if you want an explorer. This file is the Support contract even when Scalar is off. SupportCenter, SupportSection, SupportPage, and SupportTicket registrations set `openapi: { tags: ["Support"], tag: { group: "Support" } }` so Scalar and MCP docs (`RecordingStudio_MCP` `v0.30.3+`) keep those types with Support instead of ungrouped. Ticket operations use type-first titles (`Ticket - Open`, `Ticket - Update`, `Ticket - Index`, `Ticket - Show`).

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

| Actor | Public page `index` / `show` | Public ticket `index` / `show` / `open` | Operations section / nested-page `index` / `show` | Operations ticket `index` / `show` / `update` | Operations `create` / `update` / trash / move / publish / unpublish |
| --- | --- | --- | --- | --- | --- |
| Accessible `:edit` on **AdminRoot** (operations token) | Yes, with a public token that can view | Yes, with a public token (`authorize!` `:view` on the grant scope). Open and list are the grant actor's tickets | Yes | Yes when the grant also satisfies `:edit` on **SupportCenter** (HTML support team) | Yes |
| Accessible `:view` on **AdminRoot** (operations token) | Yes, with a public token that can view | Yes, as above | Yes | No — `403` (below support-team `:edit` on SupportCenter) | No — `403` |
| Workspace `:view` (or stronger) **without** AdminRoot | Yes (that workspace; drafts hidden) | Yes for that actor's tickets; another person's ticket is `404` | No — `403` | No — `403` | No — `403`; writes are not on public |
| Public token on operations | — | — | Rejected | Rejected | Rejected |
| Missing token | `401` | `401` | `401` | `401` | `401` |
| No Accessible grant | `403` / `401` | `403` / `401` | `403` / `401` | `403` / `401` | `403` / `401` |

HTML ticket roles (the API matches these): `UserMessagesController` needs a signed-in actor to list, show, and open. Show also allows the ticket owner or the support team; anyone else is denied. `SupportTicketsController#update` needs the support team: Accessible `:edit` on SupportCenter (or its parent / admin root). The JSON actor is always `AccessGrant.actor`, never a body field.

## Public API (page reads only)

Mount prefix is the host’s API engine path. Dummy uses `/recording_studio_api`. Public API version is `v1`.

| Method | Path | Who | Notes |
| --- | --- | --- | --- |
| `GET` | `/recording_studio_api/api/v1/support_pages` | `:view` | List pages. `?q=` searches articles |
| `GET` | `/recording_studio_api/api/v1/support_pages/:id` | `:view` | One page |
| `GET` | `/recording_studio_api/api/v1/support_tickets` | `:view` on the grant scope | List the grant actor's current tickets (`Tickets.current` merged with `Tickets.for_actor`) |
| `GET` | `/recording_studio_api/api/v1/support_tickets/:id` | `:view` on the grant scope | One ticket the actor opened (or support team). Someone else's ticket is `404` |
| `POST` | `/recording_studio_api/api/v1/support_tickets` | `:view` on the grant scope | Open (`Tickets.open!`). Body: `subject`, `body`, optional `priority` (`low`, `normal`, `high`) |

Public `support_sections` list/show and nested section-pages are not registered (`404` / unsupported). Public ticket `PATCH` / `DELETE` are not registered. Public page `POST` / `PATCH` / `DELETE` and public page `move` / `publish` / `unpublish` are not registered.

## Admin API (`api: :operations`, SupportCenter plus section reads and writes)

| Method | Path | Who | Notes |
| --- | --- | --- | --- |
| `GET` | `/recording_studio_api/apis/operations/v1/support_centers` | AdminRoot `:view` | List SupportCenters |
| `GET` | `/recording_studio_api/apis/operations/v1/support_centers/:id` | AdminRoot `:view` | One SupportCenter |
| `POST` | `/recording_studio_api/apis/operations/v1/support_centers` | AdminRoot `:edit` | Body: `parent_id` (AdminRoot recording). No extra serializer keys |
| `GET` | `/recording_studio_api/apis/operations/v1/support_tickets` | SupportCenter `:edit` | List current tickets (`Tickets.current`) |
| `GET` | `/recording_studio_api/apis/operations/v1/support_tickets/:id` | SupportCenter `:edit` | One ticket (`Tickets.find!`) |
| `PATCH` | `/recording_studio_api/apis/operations/v1/support_tickets/:id` | SupportCenter `:edit` | `status` (`open`, `resolved`) and/or `priority` (`low`, `normal`, `high`) via `Tickets.update!` |
| `GET` | `/recording_studio_api/apis/operations/v1/support_sections` | AdminRoot `:view` | List sections. `?q=` searches title and slug |
| `GET` | `/recording_studio_api/apis/operations/v1/support_sections/:id` | AdminRoot `:view` | One section |
| `GET` | `/recording_studio_api/apis/operations/v1/support_sections/:parent_id/pages` | AdminRoot `:view` | Pages in that section |
| `GET` | `/recording_studio_api/apis/operations/v1/support_sections/:parent_id/pages/:relationship_id` | AdminRoot `:view` | One nested page |
| `POST` | `/recording_studio_api/apis/operations/v1/support_sections` | AdminRoot `:edit` | Body: `title`, optional `icon`, `parent_id` (workspace recording) |
| `PATCH` | `/recording_studio_api/apis/operations/v1/support_sections/:id` | AdminRoot `:edit` | `title`, `icon` |
| `DELETE` | `/recording_studio_api/apis/operations/v1/support_sections/:id` | AdminRoot `:edit` | Trash (`Sections.trash!`), not a hard delete |
| `POST` | `/recording_studio_api/apis/operations/v1/support_sections/:parent_id/pages` | AdminRoot `:edit` | Parent from the URL. `title`, optional `body`, `description`, `icon` |
| `PATCH` | `/recording_studio_api/apis/operations/v1/support_sections/:parent_id/pages/:relationship_id` | AdminRoot `:edit` | Nested page revise |
| `DELETE` | `/recording_studio_api/apis/operations/v1/support_sections/:parent_id/pages/:relationship_id` | AdminRoot `:edit` | Nested page trash |
| `POST` | `/recording_studio_api/apis/operations/v1/support_pages` | AdminRoot `:edit` | Body: `title`, optional `body`, `description`, `icon`, `parent_id` (section recording) |
| `PATCH` | `/recording_studio_api/apis/operations/v1/support_pages/:id` | AdminRoot `:edit` | `title`, `description`, `icon`, `body` |
| `DELETE` | `/recording_studio_api/apis/operations/v1/support_pages/:id` | AdminRoot `:edit` | Trash (`Pages.trash!`) |
| `POST` | `/recording_studio_api/apis/operations/v1/support_pages/:id/actions/move` | AdminRoot `:edit` | Body: `parent_id` (destination section recording) |
| `POST` | `/recording_studio_api/apis/operations/v1/support_pages/:id/actions/publish` | AdminRoot `:edit` | Uses Publishable `publish`; response matches Publishable snapshot JSON |
| `POST` | `/recording_studio_api/apis/operations/v1/support_pages/:id/actions/unpublish` | AdminRoot `:edit` | Uses Publishable `unpublish`; response matches Publishable snapshot JSON |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics` | AdminRoot `:view` | Host-registered Metrics index. Includes Support ticket and page metrics |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_tickets/open` | AdminRoot `:view` | Open tickets |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_tickets/oldest_open_age` | AdminRoot `:view` | Age in seconds of the oldest open ticket (`value` omitted when there are none) |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_tickets/by_status` | AdminRoot `:view` | Tickets by status (`open` or `resolved`) |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_tickets/by_priority` | AdminRoot `:view` | Tickets by priority |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_tickets/opened` | AdminRoot `:view` | Tickets opened, bucketed by the recording's `created_at` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_tickets/avg_time_to_resolve` | AdminRoot `:view` | Mean seconds from the recording's `created_at` to `resolved_at` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_pages/total` | AdminRoot `:view` | Live (non-trashed) support pages |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/support_page_views/over_time` | AdminRoot `:view` | Page views (Views raw logs for Support pages) by `created_at` |


`group_by` (Metrics 0.3): `support_tickets.open` accepts `group_by=priority`; `support_tickets.opened` accepts `group_by=status` or `group_by=priority` with `from`/`to`/`interval`. Groups with fewer than 5 tickets fold into `other`, so groups plus `other` equal the total. `oldest_open_age`, `by_status` and `by_priority` take no `group_by`. Ticket list endpoints do not add metric filters. The catalog lists `group_by`, `min_group_size`, `date_range`, `timezone` and `freshness` for each metric.

Ticket metrics count the current snapshot once. The scope joins `RecordingStudio::Recording` on `recordable_id` where `recordable_type` is `RecordingStudioSupport::SupportTicket` and `trashed_at` is null. `opened`, `oldest_open_age`, and `avg_time_to_resolve` use the recording's `created_at` (when the ticket was opened), not a later snapshot's `created_at`. Identifiers, response shape, `blast_radius`, and `api_authorize` are unchanged. `avg_time_to_resolve` accepts `group_by=priority`.

Collection `POST` on `support_pages` needs `parent_id`. Nested `POST …/support_sections/:parent_id/pages` takes the parent from the URL. Nested create / update / destroy call the same Support page handlers as the collection routes (`Pages.create!` / `revise!` / `trash!`).

Send writable fields at the JSON root. Do not wrap them in `attributes`.

Move and trash go through Moveable `move_to!` and Trashable. Support handlers still require AdminRoot `:edit`. The **host** should set Trashable `authorization_resolver` and Moveable `authorization_hook` to `RecordingStudioSupport.support_team_permission(actor:, recording:)` so an AdminRoot-only operations client can pass those mixin checks (`nil` falls through). Dummy copies that wiring.

Orderable reorder is not allowlisted on Support pages.

## Fields

SupportCenters have no extra serializer keys or writable attributes. Create takes `parent_id` only.

Sections serialize `title`, `slug`, `icon`. Writable: `title`, `icon`. Slug is Support-owned.

Pages serialize `title`, `description`, `icon`, `body`. Writable: those four. Body is sanitized (`Body.sanitize`).

Tickets serialize `subject`, `status`, `priority`, `resolved_at`. Public writable on open: `subject`, `body`, `priority`. Operations writable on update: `status`, `priority`. Status: `open`, `resolved`. Priority: `low`, `normal`, `high`.

Recording Studio API also returns recording ids, type, and relationship metadata on each record.

## Search

There is no `GET support/search`. Public `GET …/support_pages?q=` uses `Pages.for_root` / `SupportPage.search`. Operations `GET …/support_sections?q=` uses `Sections.public_index(query:)` / `SupportSection.search` (trigram on title and slug). Nested operations `GET …/support_sections/:parent_id/pages?q=` uses `Pages.for_section`. Public workspace-only tokens hide drafts and stay scoped to that client’s workspace root. Operations AdminRoot `:view` readers see drafts.

## Examples

List live articles a workspace token can see:

```http
GET /recording_studio_api/api/v1/support_pages
Authorization: Bearer <workspace_token>
```

Create a page (operations editor token):

```http
POST /recording_studio_api/apis/operations/v1/support_pages
Authorization: Bearer <operations_token>
Content-Type: application/json

{ "title": "How do I get a receipt?", "body": "<p>Open Billing.</p>", "parent_id": "<section_recording_id>" }
```

A page `parent_id` that is not a SupportSection (for example an AdminRoot id) is `invalid_input` with a `parent_id` detail, same as section create when the parent is not a SupportCenter. A missing parent recording is still not found. Writes pass `actor:` into `record` / `revise`.

Design notes (handlers): [api-plan.md](api-plan.md).
