# Support process flows (admin / staff)

How help **pages** and **sections** move through create, edit, publish, trash, and access. Public `/help` is in scope only where it gates drafts.

Staff Support is an **Admin** surface. Accessible on the **admin root** is the gate. Workspace-only `:edit` does not open `/admin/support`.

## Tree and access

```
Workspace (root)
  └── SupportSection (Trashable, Orderable → pages)
        └── SupportPage (Trashable, Moveable, Publishable)
              └── Publishable child (status / slug / schedule)

AdminRoot (root, Accessible)  ← staff gate for Admin + /admin/support
```

| Rule | Today |
| --- | --- |
| Who “owns” content | Pages still live under a **workspace**. Staff who can use Admin may edit any workspace’s help. |
| Per-page / per-section owners | **None.** Accessible is not enabled on `SupportPage` or `SupportSection`. |
| Move between sections | Changes parent under the **same** workspace root. |
| Staff gate | Accessible on the **admin root** (same bar as `/admin`). Fail closed. |
| Public | `/help` only. `/admin/support` is never anonymous. |

Do not invent a second permission system. If a host needs section- or page-scoped authors, **stop and extend Accessible**.

---

## 1. CRUD coverage

### Roles used on staff screens

| Role | Meaning in Support |
| --- | --- |
| Logged out | Public `/help` only. `/admin/support` asks for sign-in. Old `/support` bookmarks redirect to `/admin`. |
| Workspace `:view` / `:edit` without AdminRoot | **No** staff Support. `/help` still public. |
| Accessible `:view` on AdminRoot | Admin hub + staff preview. |
| Accessible `:edit` (or `:admin`) on AdminRoot | Create / revise / trash / Publish link / drafts on staff section show. |

### Surface × action × role

Legend: **UI** = button/link on that surface · **URL** = form/route works if you have the path · **—** = not available · **Pub** = Publishable management screen (outside Support chrome)

#### Pages

| Action | Admin pages table | `/admin/support/:id` (preview) | `/admin/support/new` / `:id/edit` | Gate |
| --- | --- | --- | --- | --- |
| Create | UI (New page) | — | URL | Admin `:edit` |
| Read / preview | — | UI | — | Admin `:view` |
| Edit / revise | UI (Edit → gem form) | **No Edit CTA** | URL | Admin `:edit` |
| Trash | — | UI (icon) | — | Admin `:edit` |
| Move section | UI (Moveable) | — | — | Admin + Moveable |
| Publish / unpublish | — | Publish → Pub; no Unpublish CTA | — | Publishable + Admin `:edit` |

#### Sections

| Action | Admin sections table | `/admin/support/sections/:id` | `/admin/support/sections/new` / `:id/edit` | Gate |
| --- | --- | --- | --- | --- |
| Create | UI (New section) | — | URL | Admin `:edit` |
| Read | — | UI (staff list, including drafts) | — | Admin `:view` |
| Edit / revise | UI (Edit → gem form) | — | URL | Admin `:edit` |
| Trash (cascade pages) | — | — | Route `POST .../trash` | Admin `:edit` |
| Reorder pages | — | — | — | Orderable domain only; no Support/Admin UI |

Engine root `/admin/support` redirects to `/admin`. Admin tables replace the old staff section-browse hub.

### Gaps (wiring, not domain)

1. **Edit lives in Admin**, not on staff preview (intentional).
2. **Section trash** is domain + route only — no staff or Admin button.
3. **Page trash** is on staff preview only — not on Admin tables.
4. Admin has no Publish, Preview/Open, Restore, or Reorder actions.

---

## 2. Draft ↔ Live status

### Today

| Path | Behavior |
| --- | --- |
| Staff preview **Publish** | Links to Publishable edit (`/recordings/:id/publishable/edit`). Not an in-place toggle. |
| Staff **Live** / **Draft** button | Display-only (`type="button"`, no href/form). Shows `currently_published?`. |
| Unpublish / Live → Draft | **No Support CTA.** Possible only on the Publishable management screen. |
| Public `/help` | Hide drafts (`indexable` / `public_for_section`). |
| Staff section show | Kept drafts + status badge; open staff preview. |
| Admin status column | Badge via `currently_published?`. |

---

## 3. Versioning

| Kind | What we have | Product “versioning”? |
| --- | --- | --- |
| Gem semver | `VERSION`, CHANGELOG, MIGRATION_NOTES | Shipping the gem — **not** article history |
| Recording Studio revise | Each edit → new immutable recordable snapshot | **Yes, as history exhaust** |
| Publishable child | Live slug/status/schedule metadata | No prior-live body restore |
| Staff / Admin restore UI | **None** | Out of product UI today |

---

## 4. Ownership summary (Accessible)

1. Grant AdminRoot access for staff who use `/admin` and `/admin/support`.
2. Do not attach Accessible to SupportPage/SupportSection unless product requires page-scoped authors.
3. Moving a page between sections does not change the workspace bucket.
4. Controllers fail closed: missing actor or missing AdminRoot grant → **No access** (HTTP 403). Logged-out hits host auth first.

---

## Related code

- Models: `app/models/recording_studio_support/support_{page,section}.rb`
- Staff: `app/controllers/recording_studio_support/{pages,sections}_controller.rb`, views under `app/views/recording_studio_support/`
- Auth: `app/controllers/recording_studio_support/application_controller.rb`
- Admin: `lib/recording_studio_support/admin/{pages_screen,sections_screen,queries}.rb`
- Domain: `lib/recording_studio_support/{pages,sections}.rb`
