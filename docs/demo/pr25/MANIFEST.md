# PR 25 public help UI polish — stills

Dummy at `http://127.0.0.1:3000`. Desktop `1440×1100`. Before is `main` (`16e26b9`); after is this PR.

| File | Caption |
|---|---|
| `before-help-home-desktop.png` | `/help` on `main`: left-aligned title, default Search, stacked full-width section rows |
| `after-help-home-desktop.png` | `/help` after: centered larger title, taller Search, 3-column section cards; no Sign out or workspace switcher |
| `after-help-home-mobile.png` | `/help` after at `390×844`: centered title and taller Search; cards stack |
| `before-article-show-desktop.png` | Article show on `main`: left-aligned title, description subtitle plus a separate date line, narrower body image |
| `after-article-show-desktop.png` | Article show after: larger centered title, calendar day as the only subtitle, full-width body image in a figure |

Section show (`/help/sections/:slug`) is unchanged in this PR. `/help` on `main` already hid dummy Sign out / workspace chrome for Support controllers; the after stills confirm it stays gone.
