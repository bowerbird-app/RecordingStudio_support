# PR 25 public help UI polish — stills

Dummy at `http://127.0.0.1:3000`. Desktop `1440×1100`.

Layout polish stills. Before is `main` (`16e26b9`). After is this PR before the Content wrap.

| File | Caption |
|---|---|
| `before-help-home-desktop.png` | `/help` on `main`: left-aligned title, default Search, stacked full-width section rows |
| `after-help-home-desktop.png` | `/help` after polish: centered larger title, taller Search, 3-column section cards |
| `after-help-home-mobile.png` | `/help` after polish at `390×844` |
| `before-article-show-desktop.png` | Article on `main`: left-aligned title, description plus date, narrower image |
| `after-article-show-desktop.png` | Article after polish: larger centered title, calendar-day subtitle, full-width figure |

Content wrap stills. Before is this PR after polish, before `FlatPack::Content::Component`. After is Content + Flatpack `adc3c6ed9ea6`. Live computed type: body `p` 18px, body `h2` 30px.

| File | Caption |
|---|---|
| `before-article-content-desktop.png` | Article after polish, ContentEditor display class, 16px body |
| `after-article-content-desktop.png` | Same article in `fp-content`: 18px paragraphs, bumped headings, figure kept |

Home type did not change after the Content wrap. Section show is unchanged in this PR.
