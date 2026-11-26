# Support JSON API

How a host, person, or AI agent talks to Support sections and pages over **Recording Studio API**. Public anonymous browse stays `/help`. This surface is authenticated.

Support does **not** gemspec-depend on `recording_studio_api`. Add that gem in the **host**. Dummy pins `v1.22.0` (`>= 1.22.0`, `< 2.0`). An older API still boots: public ticket create passes `parent: :server` only when `register_resource_handler` accepts `parent:`. If the constant is missing, Support boots with no JSON routes. Only API 1.22 requires Recording Studio `>= 7.7.0`, Accessible `>= 0.50.0`, and `config/recording_studio_api.yml`. Rails raises at boot when that file is missing.

API refuses a registered path that captures `:id` unless that endpoint passes `recordable_type` or `scope_id: false`. Recording Studio API 1.21.7 also refuses to boot when a non-GET endpoint sets `scope_id: false` and omits `required_role`. Public reply and mark-read pass `required_role: :view`, the same role as `access_grant.authorize!` on the grant scope. GET `support_ticket_messages/:id` is exempt. `GET support_ticket_unread_count` does not set `scope_id: false`. Operations message routes pass `recordable_type` and leave `scope_id` unset. Messages `v0.31.0` declares the conversation recordable type, so send, read, rename, and mark-read scope the message group. Notifications `v0.19.5` and Users `v0.33.0` pass `scope_id: false` and `required_role` because those ids are notification rows and user rows. API 1.22 refuses to boot a non-GET endpoint that sets `scope_id: false` and omits `required_role`. The dummy initializer `recording_studio_api_sibling_scope.rb` still passes `scope_id: false` for any of those endpoint names that arrive without either declaration. Support's own page and ticket routes are resource handlers. They do not use that initializer.

Support **does** depend on `recording_studio_metrics` and registers site-wide Support metrics. The host calls `RecordingStudioMetrics::Api.register!(api: :operations)` once.

Do not add a Support `ApiController`. Writes go through `Pages` / `Sections`. Access is **Accessible** only.

## Install (host)

```ruby
gem "recording_studio_api", ">= 1.22.0", "< 2.0", github: "bowerbird-app/RecordingStudio_api", tag: "v1.22.0"
```

```bash
bin/rails generate recording_studio_api:install
bin/rails generate recording_studio_api:migrations
bin/rails db:migrate
```

Mount the engine (dummy uses `/recording_studio_api`). Enable `:accessible` and `:api_access_point` on roots that hold API keys. Dummy does this on `Workspace` and `AdminRoot`.

Name the Admin API `:operations` (`default_access :read_only`). Support registers **page list, show, and search** on the public API and **SupportCenter reads/create plus section reads and writes** on `:operations`. Tickets follow the same public-reads vs operations-writes split: public `index` / `show` / `open`, operations `index` / `show` / `update`. Public page and ticket registrations pass `auto_capability_actions: false`. Page writes on operations include `create` / `update` / `destroy` in `operations:` so MCP `describe` matches the handlers. Handlers register with `register_resource_handler` and call `Pages` / `Sections` / `Tickets`. The API resolves each route id through the token scope and authorizes it before the handler. Operations write handlers read `context.recording`. Public page show and public ticket show pass `owns_scoping: true` and apply Support's own filters. Pass `operations:` explicitly on the operations registrations so the named-API read-only default does not apply. List handlers read `PaginateResourceCollection` `Page` or a Hash. `CenterType.register!` owns SupportCenter type registration, including its OpenAPI tag. `TicketType.register!` owns SupportTicket.

Provision operations clients on **AdminRoot** (featured_in). Help pages, sections, and tickets live under that root's support centre, so the grant covers those records. A workspace-scoped token cannot address them. Move still accepts `parent_id`, `destination_id`, or `new_parent_id`. The handler scopes that destination through the same grant. Section create ignores trashed parents.

Live OpenAPI (Scalar) is optional and owned by the API gem. Generate it in the host if you want an explorer. This file is the Support contract even when Scalar is off. Operations SupportCenter, SupportSection, SupportPage, and SupportTicket registrations set `openapi: { tags: ["Support"], tag: { group: "Support" } }` so those types stay in the group Support. Public SupportPage sets `tags: ["Support Page"]` in that same group, matching `support_page_search`. Public SupportTicket sets `tags: ["Support Ticket"]` and `tag: { group: "Support Ticket" }`, so list, show, and open sit in their own group. Ticket message endpoints use the tag and group Support Messages. Each resource operation sets an action-first `title` and the same `summary`: List support pages, Show support page, Create support page, Update support page, Trash support page, and the matching section, center, and ticket titles. Opening a ticket is Open support ticket.

Capability actions on the operations API set a per-type title. Pages: Move support page, Publish support page, Unpublish support page, Update support page publishing. Sections: Reorder support section, Move page in support section. Centers: List support center access, Grant support center access, Update support center access, Revoke support center access. Trash actions (trash, restore, purge, list) use the group Support Trash and titles such as Trash support page, Restore support page, Trash support section, Purge support trash, and List support trash. Publish support page and Unpublish support page are Support's own titles, so a shared Publish press kit title on the capability action does not replace them. The public API does not register those actions.

Recording Studio MCP 0.45.2 named tools come from `RecordingStudioSupport::McpCopy`. Hosts that load MCP call `include_tools(*RecordingStudioSupport::McpCopy.tool_names(api: :public))` on the public server and the operations list on the operations server. Support does not gemspec-depend on MCP. Named typed tools sit under the Support type tags. The four ticket-message tools sit under Support Messages. Operations also includes `close_support_ticket` and Support catalog metric names (`support_tickets-open`, `support_tickets-oldest_open_age`, `support_tickets-by_status`, `support_tickets-by_priority`, `support_tickets-opened`, `support_tickets-avg_time_to_resolve`, `support_pages-total`, `support_page_views-over_time`). Those metric names are not on the public server and are not `register_tool` targets. Trash, restore, purge, and access grants stay on Trashable and Accessible; this gem does not register those names. Capability OpenAPI still sets per-type titles and `tag_suffix` Trash for operations trash actions. Public search stays `search_support_pages`.

Recording Studio API 1.2.1 files a tag that is not a resource name under the Scalar folder API. Support Trash and Support Messages are that kind of tag. The four message operations still share one tag. Nested section page routes keep the API gem's own summaries.

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

| Actor | Public page `index` / `show` | Public ticket `index` / `show` / `open` | Operations section / nested-page `index` / `show` | Operations ticket `index` / `show` | Operations ticket `update` / close / reply | Operations `create` / `update` / trash / move / publish / unpublish |
| --- | --- | --- | --- | --- | --- | --- |
| Accessible `:edit` on **AdminRoot** (operations token) | Yes, with a public token that can view | Yes, with a public token (`authorize!` `:view` on the grant scope). Open and list are the grant actor's tickets | Yes | Yes | Yes when the grant also satisfies `:edit` on **SupportCenter** (HTML support team) | Yes |
| Accessible `:view` on **AdminRoot** (operations token) | Yes, with a public token that can view | Yes, as above | Yes | Yes | No — `403` (below support-team `:edit` on SupportCenter) | No — `403` |
| Workspace `:view` (or stronger) **without** AdminRoot | Yes (that workspace; drafts hidden) | Yes for that actor's tickets; another person's ticket is `404` | No — `403` | No — `403` | No — `403` | No — `403`; writes are not on public |
| Public token on operations | — | — | Rejected | Rejected | Rejected | Rejected |
| Missing token | `401` | `401` | `401` | `401` | `401` | `401` |
| No Accessible grant | `403` / `401` | `403` / `401` | `403` / `401` | `403` / `401` | `403` / `401` | `403` / `401` |

HTML ticket roles: `UserMessagesController` needs a signed-in actor to list, show, and open. The list is `Tickets.for_actor`. A customer's list is conversations they can `:view` (their `:edit` grant). A support-team actor's list is tickets they created, so inherited access does not list every ticket. Show allows Accessible `:view` on that conversation, which covers the customer and staff who inherit access from SupportCenter or AdminRoot. Anyone else is denied. `SupportTicketsController#update` needs the support team: Accessible `:edit` on SupportCenter (or its parent / admin root). The JSON actor is always `AccessGrant.actor`, never a body field. Public ticket index and show use `Tickets.for_actor`, so a support-team public client sees tickets that client created. Operations ticket index and show stay `Tickets.current`.

## Public API (list, show, and search)

Mount prefix is the host’s API engine path. Dummy uses `/recording_studio_api`. Public API version is `v1`.

| Method | Path | Who | Notes |
| --- | --- | --- | --- |
| `GET` | `/recording_studio_api/api/v1/support_pages` | `:view` | List pages. `?q=` searches articles. A support-team token also sees drafts |
| `GET` | `/recording_studio_api/api/v1/support_pages/:id` | `:view` on the token scope | One published page in the current support centre |
| `GET` | `/recording_studio_api/api/v1/support_page_search` | `:view` | Published pages only, including for a support-team token. `?q=` matches title and body |
| `GET` | `/recording_studio_api/api/v1/support_tickets` | `:view` on the grant scope | List the grant actor's current tickets (`Tickets.current` merged with `Tickets.for_actor`) |
| `GET` | `/recording_studio_api/api/v1/support_tickets/:id` | `:view` on the grant scope | One ticket on the actor's own list. A support-team actor's list is tickets they created. Someone else's ticket is `404` |
| `POST` | `/recording_studio_api/api/v1/support_tickets` | `:view` on the grant scope | Open (`Tickets.open!`). Body: `subject`, `body`, optional `priority` (`low`, `normal`, `high`). Creates the ticket, tagged conversation, and first message |
| `GET` | `/recording_studio_api/api/v1/support_ticket_messages/:id` | `:view` on the grant scope, then Accessible `:view` on the tagged conversation | Messages on that ticket, oldest first (`RecordingStudioMessages.message_recordings`). Path is not under `support_tickets/:id` because the API treats that prefix as the ticket resource |
| `POST` | `/recording_studio_api/api/v1/support_ticket_reply/:id` | same, plus Accessible `:edit` on the conversation for `send_message` | Body: `body`. A requester reply reopens a resolved ticket. The reopen `updated` event actor is a support-team person; `impersonator` is the requester; `metadata` has Messages `message_id` / `message_group_id` |
| `POST` | `/recording_studio_api/api/v1/support_ticket_mark_read/:id` | same as list messages | Marks that conversation read for the grant actor |
| `GET` | `/recording_studio_api/api/v1/support_ticket_unread_count` | `:view` on the grant scope | `unread_count` for the same tickets as `list_support_tickets` |

Public `support_sections` list/show and nested section-pages are not registered (`404` / unsupported). Public ticket `PATCH` / `DELETE` are not registered. Public page `POST` / `PATCH` / `DELETE` are not registered. Public page move, publish, unpublish, update publishing, trash, restore, purge, and list trash are not registered. A missing token receives `401`. A signed-in public token receives `404` or `422`. Those actions stay on the operations API.

## Admin API (`api: :operations`, SupportCenter plus section reads and writes)

| Method | Path | Who | Notes |
| --- | --- | --- | --- |
| `GET` | `/recording_studio_api/apis/operations/v1/support_centers` | AdminRoot `:view` | List SupportCenters |
| `GET` | `/recording_studio_api/apis/operations/v1/support_centers/:id` | AdminRoot `:view` | One SupportCenter |
| `POST` | `/recording_studio_api/apis/operations/v1/support_centers` | AdminRoot `:edit` | Body: `parent_id` (AdminRoot recording). No extra serializer keys |
| `GET` | `/recording_studio_api/apis/operations/v1/support_tickets` | AdminRoot `:view` | List current tickets (`Tickets.current`) |
| `GET` | `/recording_studio_api/apis/operations/v1/support_tickets/:id` | AdminRoot `:view` | One ticket (`Tickets.find!`). Id may be the recording id or the SupportTicket id |
| `PATCH` | `/recording_studio_api/apis/operations/v1/support_tickets/:id` | SupportCenter `:edit` | `status` (`open`, `resolved`) and/or `priority` (`low`, `normal`, `high`) via `Tickets.update!`. Id is the recording id |
| `POST` | `/recording_studio_api/apis/operations/v1/support_ticket_close/:id` | SupportCenter `:edit` | Resolve that ticket through `Tickets.update!`. Already resolved is unchanged. Not on the public API. MCP name `close_support_ticket` |
| `GET` | `/recording_studio_api/apis/operations/v1/support_ticket_messages/:id` | AdminRoot `:view`, then Accessible `:view` on the conversation | Same ticket-keyed message list as public |
| `POST` | `/recording_studio_api/apis/operations/v1/support_ticket_reply/:id` | SupportCenter `:edit`, then Accessible `:edit` on the conversation | Staff reply. Does not reopen a resolved ticket |
| `POST` | `/recording_studio_api/apis/operations/v1/support_ticket_mark_read/:id` | SupportCenter `:edit` | Marks that conversation read for the grant actor |
| `GET` | `/recording_studio_api/apis/operations/v1/support_ticket_unread_count` | AdminRoot `:view` | `unread_count` across current tickets |
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

Ticket metrics count the current snapshot once. The scope joins `RecordingStudio::Recording` on `recordable_id` where `recordable_type` is `RecordingStudioSupport::SupportTicket` and the row is in `Recording.kept`. `opened`, `oldest_open_age`, and `avg_time_to_resolve` use the recording's `created_at` (when the ticket was opened), not a later snapshot's `created_at`. Identifiers, response shape, `blast_radius`, and `api_authorize` are unchanged. `avg_time_to_resolve` accepts `group_by=priority`.

Collection `POST` on `support_pages` needs `parent_id`. Nested `POST …/support_sections/:parent_id/pages` takes the parent from the URL. Nested create / update / destroy call the same Support page handlers as the collection routes (`Pages.create!` / `revise!` / `trash!`).

Send writable fields at the JSON root. Do not wrap them in `attributes`.

Move and trash go through Moveable `move_to!` and Trashable. Support handlers still require AdminRoot `:edit`. The **host** should set Trashable `authorization_resolver` and Moveable `authorization_hook` to `RecordingStudioSupport.support_team_permission(actor:, recording:)` so an AdminRoot-only operations client can pass those mixin checks (`nil` falls through). Dummy copies that wiring.

Orderable reorder is not allowlisted on Support pages.

## Fields

SupportCenters have no extra serializer keys or writable attributes. Create takes `parent_id` only.

Sections serialize `title`, `slug`, `icon`. Writable: `title`, `icon`. Slug is Support-owned.

Pages serialize `title`, `description`, `icon`, `body`. Writable: those four. Body is sanitized (`Body.sanitize`).

Tickets serialize `subject`, `status`, `priority`, `resolved_at`. Public writable on open: `subject`, `body`, `priority`. `subject` and `body` are required. `priority` is optional and must be one of `SupportTicket::PRIORITIES` (`low`, `normal`, `high`). An unknown value (for example `urgent`) is `invalid_input` with `priority must be` plus that list joined with `or`. The same check runs on operations update. When the loaded API accepts `parent:` on `register_resource_handler` (API 1.22), public create registers `parent: :server`. The published create schema, catalog, and MCP input then omit `parent_id`, and a sent `parent_id` is ignored. On an older API the registration matches 0.38.8 and the MCP open description says to leave `parent_id` blank. Support files the ticket under the support centre either way. Operations writable on update: `status`, `priority`. Close takes the ticket id only. Status: `open`, `resolved`. Priority: `low`, `normal`, `high`.

Recording Studio API also returns recording ids, type, and relationship metadata on each record.

## Search

There is no `GET support/search`. Public `GET …/support_page_search?q=` uses `Pages.for_root` / `SupportPage.search` (pg_trgm on title and body) and keeps customer-visible published pages (Accessible view audience), so drafts and trashed pages stay out and a published page with no indexable URL stays in. Public `GET …/support_pages?q=` uses the same search and still returns drafts to a support-team token. Operations `GET …/support_sections?q=` uses `Sections.public_index(query:)` / `SupportSection.search` (trigram on title and slug). Nested operations `GET …/support_sections/:parent_id/pages?q=` uses `Pages.for_section`. Public page show returns a published page in the current support centre. A draft, or a page in another centre, is not found. The API does not resolve that id through the workspace token. Operations AdminRoot `:view` readers see drafts. Operations AdminRoot `:view` can list and show tickets and ticket messages. Ticket update, close, reply, and mark-read still need SupportCenter `:edit`.

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
