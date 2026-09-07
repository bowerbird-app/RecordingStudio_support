# Support process flows (admin / staff)

How help **pages** and **sections** move through create, edit, publish, trash, and access after `0.7.3`. Public `/help` is in scope only where it gates drafts.

Ownership (workspace-root Accessible) is implemented in Support authorize. Other rows below still mark wiring gaps for later work.

## Tree and access (ownership)

```
Workspace (root, Accessible)
  └── SupportSection (Trashable, Orderable → pages)
        └── SupportPage (Trashable, Moveable, Publishable)
              └── Publishable child (status / slug / schedule)

AdminRoot (root, Accessible)  ← Admin hub only; not a content parent
```

| Rule | Today |
| --- | --- |
| Who “owns” content | The **workspace root**. Actors get Accessible grants on that root (and/or AdminRoot). |
| Per-page / per-section owners | **None.** Accessible is not enabled on `SupportPage` or `SupportSection`. |
| Move between sections | Changes parent under the **same** workspace root. ACL does not move; it stays root-scoped. |
| Admin vs workspace editor | Same content model. Admin staff may authorize via AdminRoot grant even when current root is Admin; creates still land under a Workspace. |
| How authorize decides | Load the page/section (or parent section on create) **first**. Check Accessible on that content’s workspace root, **or** AdminRoot. Do not use the switched current root once a content root is known — that blocked cross-workspace ID attacks. |
| Accessible gap? | Root-scoped `:edit` is enough for “any editor in this workspace.” If a host needs section- or page-scoped authors, **stop and extend Accessible** — do not invent ad-hoc ownership. |

Ownership is implemented in Support controllers. Remaining follow-ups are CRUD CTAs, Draft ↔ Live, and versioning — not a second permission system.

---

## 1. CRUD coverage

### Roles used on staff screens

| Role | Meaning in Support |
| --- | --- |
| Logged out | Section index/show readable; no write CTAs; page preview `/support/:id` needs sign-in + `:view`. |
| Accessible `:view` on workspace | Staff page preview; published-only section lists. |
| Accessible `:edit` (or AdminRoot grant that passes `:edit`) | Create / revise / trash / Publish link / see drafts on section show. |

Authorize checks Accessible on the **page/section workspace root** (loaded before authorize) or AdminRoot — not on the page/section recording itself, and not on a mismatched switched current root once content is known.

### Surface × action × role

Legend: **UI** = button/link on that surface · **URL** = form/route works if you have the path · **—** = not available · **Pub** = Publishable management screen (outside Support chrome)

#### Pages

| Action | `/support` | `/support/sections/:id` | `/support/:id` (preview) | Admin pages table | Gate |
| --- | --- | --- | --- | --- | --- |
| Create | UI (New page) for `:edit` | UI (New page) for `:edit` | — | UI (New page) | `:edit` |
| Read / preview | — | Link to preview (`:edit`) or live URL (others) | UI | — (no Open/Preview action) | `:view` on preview |
| Edit / revise | — | — | **No Edit CTA** (by design) | UI (Edit → gem form) | `:edit` |
| Trash | — | — | UI (icon) for `:edit` | — | `:edit` |
| Move section | — | — | — | UI (Moveable) | Admin + Moveable |
| Publish / unpublish | — | — | Publish → Pub; no Unpublish CTA | — | Publishable + `:edit` on page (host authorizer) |

#### Sections

| Action | `/support` | `/support/sections/:id` | Admin sections table | Gate |
| --- | --- | --- | --- | --- |
| Create | UI (New section) for `:edit` | — | UI (New section) | `:edit` |
| Read | UI | UI | — | public index/show (no role) |
| Edit / revise | — | — | UI (Edit → gem form) | `:edit` |
| Trash (cascade pages) | — | — | — | Route `POST .../trash` exists; **no UI** |
| Reorder pages | — | — | — | Orderable domain only; no Support/Admin UI |

### Gaps (wiring, not domain)

1. **Edit lives in Admin**, not on staff preview or section show (intentional since 0.6; README says keep Edit off owner preview).
2. **Section trash** is domain + route only — no staff or Admin button.
3. **Page trash** is on staff preview only — not on Admin tables.
4. Admin has no Publish, Preview/Open, Restore, or Reorder actions.
5. Staff hub section **counts** stay published-only even for editors; section **show** lists drafts for `:edit`.

### Desired matrix (later work)

Confirm product intent, then implement:

| Decision | Options |
| --- | --- |
| Cross-workspace ID access | Done: authorize uses the loaded recording’s root (or AdminRoot) |
| Where editors revise | Keep Admin-only Edit **or** add Edit on staff preview / section row |
---

## 2. Draft ↔ Live status

### Today

| Path | Behavior |
| --- | --- |
| Staff preview **Publish** | Links to Publishable edit (`/recordings/:id/publishable/edit`). Not an in-place toggle. |
| Staff **Live** / **Draft** button | Display-only (`type="button"`, no href/form). Shows `currently_published?`. |
| Unpublish / Live → Draft | **No Support CTA.** Possible only on the Publishable management screen (status / schedule fields). |
| Public `/help` and non-editor `/support` | Hide drafts (`indexable` / `public_for_section`). |
| Editors on `/support/sections/:id` | See kept drafts + Publishable status badge; open staff preview. |
| Admin status column | Badge via `currently_published?`. |
| Admin Published/Draft filter | `SupportPage.published` ids — may diverge from `currently_published?` / `indexable` when schedule windows exist. |

### Desired transitions (later work)

| Transition | Who | Preferred owner |
| --- | --- | --- |
| Draft → Live | `:edit` / admin | Keep Publishable screen **or** one-click Publish on staff preview that sets published |
| Live → Draft | `:edit` / admin | Explicit Unpublish / “Move to draft” on staff preview and/or Admin row; still write through Publishable Update |
| Schedule publish/unpublish | optional | Stay on Publishable only unless product wants Support chrome |

Pick **one** public predicate for lists, badges, and Admin filters (`indexable` vs `currently_published?` vs `.published`) so scheduled windows do not lie.

---

## 3. Versioning

| Kind | What we have | Product “versioning”? |
| --- | --- | --- |
| Gem semver (`0.7.x`) | `VERSION`, CHANGELOG, MIGRATION_NOTES | Shipping the gem — **not** article history |
| Recording Studio revise | Each edit → new immutable recordable snapshot; recording id stable; events for trash/move/etc. | **Yes, as history exhaust** — not a user-facing version product |
| Publishable child | Live slug/status/schedule metadata — **not** a frozen copy of the body | No prior-live body restore |
| Staff / Admin restore UI | **None** (no revision list, compare, or restore) | Out of product UI today |
| Trash restore | Trashable API only; no Support route/UI | Separate from content versions |

**Decision for later:** document-only for now — “we have revise/event history, not a restore/compare product.” Build restore UI only if product asks; do not conflate with gem version bumps.

---

## 4. Ownership summary (Accessible)

1. Grant `:view` / `:edit` on the **workspace root** for editors and readers of that bucket.
2. Grant AdminRoot access for staff who use `/admin` (and who may edit via admin resolver when current root is Admin).
3. Do not attach Accessible to SupportPage/SupportSection unless product requires page-scoped authors — and then extend Accessible properly.
4. Moving a page between sections does not change ownership; it stays in the workspace bucket.
5. Controllers load the page/section (or create parent section) before `authorize_support!`, then check that content’s root or AdminRoot. Unauthorized **edit** / **update** redirects to show. Other denied writes render a **No access** screen (HTTP 403).

---

## Follow-up implementation order

1. **Ownership / access** — **done** for root-scoped Accessible (content root before authorize; AdminRoot still allowed).
2. **CRUD audit against that model** — close UI gaps (section trash, Admin trash/open, optional staff Edit) without inventing a second permission system.
3. **Draft ↔ Live** — bidirectional, discoverable transitions; one status source of truth for Admin + staff + public.
4. **Versioning** — keep document-only unless restore/compare is explicitly in scope.

## Related code

- Models: `app/models/recording_studio_support/support_{page,section}.rb`
- Staff: `app/controllers/recording_studio_support/{pages,sections}_controller.rb`, views under `app/views/recording_studio_support/`
- Auth: `app/controllers/recording_studio_support/application_controller.rb`
- Admin: `lib/recording_studio_support/admin/{pages_screen,sections_screen,queries}.rb`
- Domain: `lib/recording_studio_support/{pages,sections}.rb`
