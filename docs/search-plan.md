# Support search — implementation plan

Replace the current `ILIKE` filters with a config-switched search stack. Default stays Postgres full-text + trigram. Optional second backend adds embeddings via pgvector, with trigram as fallback.

This plan is for **RecordingStudio_support**. It does not propose a new ecosystem gem yet (searchable is not on the approved kit list). If a host-wide mixin is needed later, extract after Support ships a working path.

## Current state

| Surface | Today |
|---|---|
| Public `/help?q=` | Section **title** `ILIKE` |
| Public section show `?q=` | In-section page **title + body** `ILIKE` |
| Staff section show / Admin tables | Same `ILIKE` via `Pages.apply_query` / `Sections.apply_query` |
| Indexes | None for search |
| Jobs | None in the gem |
| Config | `RecordingStudioSupport.configure` initializer (paths, titles, contact) |

Core choke points to replace (keep the Flatpack Search UI and `q` param):

- `RecordingStudioSupport::Pages::Lookups#apply_query` / `#apply_page_query`
- `RecordingStudioSupport::Sections.apply_query`
- Admin `Queries.search_*` (already delegates into those)

Do **not** add Elasticsearch / Searchkick (explicit non-goal in existing tests and notes).

## Design constraints

1. **Initializer config** — match other Recording Studio addons (`RecordingStudioAI.configure`, Support’s existing `configure` block). Hosts flip backends there, not with ENV-only switches for behaviour.
2. **Recordables are immutable** — `SupportPage` / `SupportSection` change via `revise` (new snapshot row). A Postgres **generated** `search_vector` on the recordable table is fine: each new snapshot recomputes it. **Embedding columns must not be mutated on the recordable** after insert. Store embeddings on a side table keyed by `recording_id` (same pattern as `recording_studio_support_page_views`: fact/index data, not a Recording).
3. **Search query cache is not a Recording** — keyword → embedding rows are high-churn cache. Use a normal table (`recording_studio_support_searches`), not the tree.
4. **AI is injectable** — do not hard-code OpenAI/Gemini SDKs in Support. Config supplies platform + model + a callable/client. Hosts may wire `recording_studio_ai`, credentials, or a test double.
5. **Generators enable models** — hosts (and Support itself) opt models in with a generator, same spirit as mixin enablement: installing the gem does not silently alter every table.

## Config surface

Extend `RecordingStudioSupport::Configuration` and the install initializer template:

```ruby
RecordingStudioSupport.configure do |config|
  # :pg_trgm (default) | :pgvector
  config.search_backend = :pg_trgm

  # Variant 2 only — ignored when backend is :pg_trgm
  config.embedding_platform = :openai   # or :gemini, :custom
  config.embedding_model = "text-embedding-3-small"
  config.embedding_dimensions = 1536
  config.embedding_distance = :cosine   # operator choice for ORDER BY

  # Platform-agnostic: host injects how to turn text into a float vector.
  # Signature: ->(text:, model:) { Array<Float> }
  # Return nil/raise → search falls back to pg_trgm for that request.
  config.embedding_client = nil

  # Optional: which recordable types use page/section search helpers.
  # Generators still own the schema; this lists runtime participants.
  config.searchable_page_types = ["RecordingStudioSupport::SupportPage"]
  config.searchable_section_types = ["RecordingStudioSupport::SupportSection"]
end
```

Secrets stay out of the gem: hosts set API keys on their own client / `RecordingStudioAI` / credentials. Support only calls `embedding_client`.

Validation on boot (when `search_backend == :pgvector`): require `embedding_client`, `embedding_model`, and positive `embedding_dimensions`. Fail loud in development/test; log + fall back to `:pg_trgm` in production if misconfigured (decision to confirm).

## Architecture

```text
Controllers / Admin filters
        │  q:
        ▼
RecordingStudioSupport::Search.query(scope, q, kind: :pages|:sections)
        │
        ├─ backend :pg_trgm ──► TrigramSearcher (tsvector @@ + similarity)
        │
        └─ backend :pgvector ─► EmbeddingSearcher
                                  │
                                  ├─ Lookup/create Search row for keyword embedding
                                  ├─ Vector distance join to page embeddings
                                  └─ on AI failure / empty vector → TrigramSearcher
```

One public entry point. Controllers keep calling `Pages.*` / `Sections.*`; those methods call `Search.query` instead of raw `ILIKE`.

---

## Variant 1 (default) — `pg_trgm` + generated `tsvector`

### Postgres extensions

Migration (gem + copied by `migrations` generator):

```ruby
enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")
# vector extension only required for variant 2
```

### Columns and indexes (per searchable model)

Generator: `rails g recording_studio_support:searchable_pg_trgm SupportPage`

Emits a host migration only if columns/indexes are missing:

```ruby
add_column :recording_studio_support_pages, :search_vector, :tsvector,
  generated_always_as: "to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, ''))",
  stored: true

add_index :recording_studio_support_pages, :search_vector, using: :gin
add_index :recording_studio_support_pages, :title,
  opclass: :gin_trgm_ops, using: :gin
```

For **sections** (title-only, no body):

```ruby
generated_always_as: "to_tsvector('english', coalesce(title, ''))"
# + GIN on search_vector and gin_trgm_ops on title
```

Generator options:

| Option | Purpose |
|---|---|
| `ModelName` (required) | Target AR model in the host or engine |
| `--columns=title,body` | Fields concatenated into `to_tsvector` (default `title,body`) |
| `--table=` | Override table name |
| `--skip-trgm-title` | Skip typo index on title |

Also ship gem migrations that enable the columns on `SupportPage` and `SupportSection` so dummy/CI work out of the box. The generator is for hosts that add other models, or for upgrading hosts that already migrated Support tables without search columns.

### Query behaviour

For a non-blank term:

1. Build `plainto_tsquery('english', :q)` (or `websearch_to_tsquery` if we want OR/phrase UX — prefer `websearch_to_tsquery` for public help).
2. Rank with `ts_rank_cd(search_vector, query)`.
3. Also match typos: `title % :q` / `similarity(title, :q)` via `pg_trgm`, with a minimum similarity threshold (config default `0.3`).
4. Combine with `OR`, order by best rank/similarity, keep existing scope filters (published, section parent, trash).

Empty `q` returns the unfiltered relation (same as today).

### Immutability note

No worker. No writes after `revise`. Generated column updates automatically on each new recordable snapshot.

---

## Variant 2 — `pgvector` embeddings (+ trigram fallback)

### Extra extensions and tables

```ruby
enable_extension "vector" unless extension_enabled?("vector")
```

**Document embeddings** (side table — not a recordable):

```text
recording_studio_support_search_documents
  id              uuid PK
  recording_id    uuid NOT NULL, indexed, unique
  recordable_type string NOT NULL
  embedding       vector(N)   -- N from config at migrate time; see dimensions note
  embedding_at    datetime
  embedding_model string
  content_digest  string      -- hash of title+body used; skip re-embed if unchanged
  created_at / updated_at
```

Generator: `rails g recording_studio_support:searchable_pgvector SupportPage`

- Ensures variant-1 columns exist first (fallback path), or depends on them.
- Creates/updates the documents table (shared across searchable types via `recordable_type`).
- Does **not** add `embedding*` columns onto the immutable recordable table.

**Why not columns on the model:** Support pages are immutable snapshots. An async worker must write `embedding` / `embedding_at` / `embedding_model` after the AI returns. Mutating the recordable breaks Recording Studio rules; `revise`-to-store-embedding would create junk history. Side table keyed by stable `recording_id` is the correct shape (see `recording-studio-data-shape`: search indexes are derived data).

If a host uses the generator on a **non-recordable** ActiveRecord model, the generator may add `embedding`, `embedding_at`, `embedding_model` directly on that table instead — documented fork in the generator README.

**Dimensions note:** `vector(N)` is fixed at migrate time. Generator reads `RecordingStudioSupport.configuration.embedding_dimensions` (default 1536). Changing model/dimensions later needs a new migration and a full re-embed. Document in upgrade notes.

**Keyword embedding cache** (“Search” table):

```text
recording_studio_support_searches
  id              uuid PK
  keyword         string NOT NULL  -- normalized (strip, squeeze, downcase)
  embedding       vector(N)
  embedding_model string NOT NULL
  embedding_at    datetime NOT NULL
  hit_count       integer default 0
  created_at / updated_at
  unique index on [keyword, embedding_model]
```

### Embedding worker (async, platform-agnostic)

`RecordingStudioSupport::EmbedSearchDocumentJob < ActiveJob::Base`

Trigger:

- After successful `Pages.create!` / `revise!` / section create-revise (hooks or explicit enqueue in domain methods).
- Idempotent: `idempotency_key` / job args include `recording_id` + `content_digest`.
- Skip if digest matches existing document row for the same model.

Job body:

1. Load current recording + recordable text (`title`, `body`, …).
2. Call `configuration.embedding_client.call(text:, model: configuration.embedding_model)`.
3. Upsert `search_documents` row with vector, `embedding_at`, `embedding_model`, digest.
4. On client error: leave stale/missing embedding; search will miss this doc in vector mode and still be findable via trigram fallback when the whole query falls back — optionally also keep trigram always as a hybrid (see open questions).

No SDK requires in the gemspec. Client is host-injected:

```ruby
config.embedding_client = ->(text:, model:) {
  # Example only — host chooses platform
  MyEmbeddings.embed(text, model: model)
}
```

### Search request flow (variant 2)

```text
normalized = normalize(q)
row = Search.find_by(keyword: normalized, embedding_model: config.embedding_model)

if row
  query_embedding = row.embedding
  row.increment!(:hit_count)   # or counter cache / touch
else
  query_embedding = config.embedding_client.call(text: normalized, model: ...)
  if query_embedding.blank?
    return TrigramSearcher.call(...)   # fallback
  end
  Search.create!(keyword:, embedding:, embedding_model:, embedding_at: Time.current)
end

results = documents nearest to query_embedding
  scoped to the same relation filters (section, published, …)
  ORDER BY embedding <=> query_embedding  -- or cosine distance
  LIMIT …

if results empty and config allows
  TrigramSearcher.call(...)              # soft fallback
end
```

“Direct match” means **exact normalized keyword + same embedding_model** before any AI call.

### Fallback rules

| Condition | Behaviour |
|---|---|
| `search_backend != :pgvector` | Trigram only |
| Embedding client nil / raises / returns blank | Trigram for that request |
| No document rows yet (cold start) | Trigram (or empty + trigram) |
| Vector returns hits | Return those (ranked by distance) |

Always keep variant-1 indexes in place when variant 2 is on so fallback is cheap.

---

## Generators summary

| Generator | Creates |
|---|---|
| `recording_studio_support:searchable_pg_trgm NAME` | Extension check, `search_vector` generated column, GIN indexes |
| `recording_studio_support:searchable_pgvector NAME` | Depends on trigram setup; documents table / model columns; ensures `searches` table migration exists once |
| Existing `install` | Document new config keys in initializer template + INSTALL.md |
| Existing `migrations` | Copy new gem migrations with fresh timestamps |

Prefer one shared migration for `searches` and `search_documents` in the gem’s `db/migrate`, plus model-specific generators that only add the per-table `search_vector` pieces.

---

## Code layout (proposed)

```text
lib/recording_studio_support/
  configuration.rb          # new attrs + validation
  search.rb                 # facade
  search/
    normalize.rb
    trigram_searcher.rb
    embedding_searcher.rb
    embedding_client.rb     # thin wrapper: call config client, rescue → nil
  embed_search_document_job.rb   # or app/jobs/...

app/models/recording_studio_support/
  search.rb                 # keyword cache AR model (name: Search)
  search_document.rb

lib/generators/recording_studio_support/
  searchable_pg_trgm/
  searchable_pgvector/

db/migrate/
  *_enable_pg_trgm.rb
  *_add_search_vector_to_support_pages.rb
  *_add_search_vector_to_support_sections.rb
  *_create_support_search_documents.rb   # variant 2 schema always shippable; unused until backend on
  *_create_support_searches.rb
```

Ship variant-2 tables even when default backend is trigram so flipping config does not require a surprise migrate in production — or gate the vector migrations behind the pgvector generator only. **Recommendation:** gem migrations create trigram columns for Support tables always; vector tables come from the pgvector generator / an explicit `search:vector_migrations` task so hosts that never want AI do not need the `vector` extension.

---

## UI and product behaviour

- Keep Flatpack `Search` partial and `q` param. No new search chrome in v1 of this work.
- Ranking changes under the hood only.
- Optional follow-up (out of scope unless requested): global page search on `/help?q=` (today only section titles). Better backends make that product change more useful; call it out as a separate UX decision.

Copy stays human (`Search support`, `Search in {section}…`). No “embedding” / “vector” words on screens.

---

## Tests

Follow `recording-studio-tests` (gem + dummy).

| Area | Coverage |
|---|---|
| Config | Default `:pg_trgm`; pgvector requires client; unknown backend rejected |
| Trigram | Title hit, body hit, typo via trgm, blank query, scoped to section/published |
| Embedding | Cache hit skips client; cache miss calls client and stores Search; client failure → trigram; distance order |
| Job | Enqueues on create/revise; skips unchanged digest; upserts document |
| Generators | Migration content; skip-if-exists; column list option |
| Upgrade | Host with old ILIKE behaviour gets trigram after migrate; flipping backend covered |
| Regression | Admin filters and public controllers still pass `q` through |

Dummy needs `pg_trgm` (and `vector` when testing variant 2) in Postgres 16 CI/devcontainer. Add CI service notes if extensions are missing.

Coverage bar: meaningful tests for new behaviour; keep overall suite near the project bar.

---

## Docs and release

- README: search backends, initializer example, generator commands, fallback behaviour.
- `MIGRATION_NOTES` / CHANGELOG: enable extensions, run generators/migrations, set `embedding_client` before switching backend.
- Bump gem version **once** on the implementation branch (strictly greater than remote `main`).
- Update `docs/process-flows.md` only if staff/public search semantics change (e.g. global page search).

---

## Implementation phases

### Phase 0 — Decide open questions (blockers)

See below. Do not start schema until embeddings storage and migration packaging are agreed.

### Phase 1 — Trigram backend (default)

1. Config `search_backend` (default `:pg_trgm`).
2. Extensions + `search_vector` on Support pages/sections.
3. `Search::TrigramSearcher` + wire `Pages` / `Sections` apply_query.
4. Generator `searchable_pg_trgm`.
5. Tests + README + version bump notes.

Ship this alone if needed; product already improves over `ILIKE`.

### Phase 2 — Vector backend

1. `search_documents` + `searches` tables (via generator or gated migrations).
2. Injectable client + job + enqueue on page/section writes.
3. `EmbeddingSearcher` + fallback.
4. Generator `searchable_pgvector`.
5. Dummy/CI with `vector` extension; tests for cache and fallback.
6. Upgrade notes for flipping `search_backend`.

### Phase 3 — Polish (optional)

- Hybrid rank (vector + trigram in one query).
- Global `/help` page search.
- Admin widget for embedding backfill / failed jobs.
- Expire or cap `searches` cache rows.

---

## Open questions

1. **Embeddings storage** — Confirm side table on `recording_id` (recommended) vs forcing columns onto the recordable (conflicts with immutability). Plan assumes side table for Support; direct columns only for non-recordable host models.
2. **Vector migrations packaging** — Always ship in gem migrations (requires `vector` everywhere) vs only via `searchable_pgvector` generator?
3. **AI dependency** — Injectable client only (recommended), or optional soft dependency on `recording_studio_ai` with a built-in adapter?
4. **Production misconfig** — Hard fail vs silent fallback to trigram when `search_backend = :pgvector` but client missing?
5. **Hybrid vs pure fallback** — On vector backend, always merge trigram hits, or only when embeddings fail / return empty?
6. **Public `/help?q=` scope** — Keep section-title-only, or expand to pages once backends land?
7. **Extract gem later?** — Stay in Support for now; extract `recording_studio_searchable` only if another product needs the same stack (would need an addition to the approved gems list).

---

## Out of scope

- Elasticsearch / OpenSearch / Searchkick
- Changing Flatpack Search component API
- Per-user personalized ranking
- Storing raw LLM chat in the Search table
- Making `Search` or `SearchDocument` a Recording / recordable
