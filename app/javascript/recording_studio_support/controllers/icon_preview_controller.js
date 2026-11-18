import { Controller } from "@hotwired/stimulus"

// Loads a server-rendered Heroicon into the preview frame when the icon
// field changes. FlatPack 0.2 draws the SVG in the HTML. Setting a name
// from JavaScript does not.
export default class extends Controller {
  static values = {
    inputName: { type: String, default: "section[icon]" },
    sectionIcons: { type: Object, default: {} },
    previewUrl: String
  }

  connect() {
    this.trackedSectionDefault = this.normalize(this.iconInput?.value || "")
  }

  sync() {
    this.refresh()
  }

  sectionChanged(event) {
    const select = event.target
    if (!select || select.name !== "page[section_id]") return

    const nextDefault = this.normalize(this.sectionIconsValue[select.value] || "")
    const input = this.iconInput
    if (!input) return

    const current = this.normalize(input.value)
    const stillOnPreviousDefault =
      current === "" || current === this.normalize(this.trackedSectionDefault || "")

    if (!stillOnPreviousDefault) return

    input.value = nextDefault
    this.trackedSectionDefault = nextDefault
    this.refresh()
  }

  refresh() {
    const frame = this.element.querySelector("#support_icon_preview")
    if (!frame || !this.hasPreviewUrlValue) return

    const name = this.normalize(this.iconInput?.value || "")
    const url = new URL(this.previewUrlValue, window.location.origin)
    if (name) {
      url.searchParams.set("name", name)
    } else {
      url.searchParams.delete("name")
    }

    const next = `${url.pathname}${url.search}`
    if (frame.getAttribute("src") === next) return

    frame.src = next
  }

  normalize(raw) {
    return raw.toString().trim().toLowerCase().replaceAll("_", "-")
  }

  get iconInput() {
    return this.element.querySelector(`input[name="${this.inputNameValue}"]`)
  }
}
