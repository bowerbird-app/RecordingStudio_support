import { Controller } from "@hotwired/stimulus"

// Keeps a Heroicons preview in sync with an Icon field (section or page forms).
// FlatPack::Shared::IconComponent renders an empty SVG shell; flat-pack--icon
// fills the paths. Do not wipe those paths unless the name actually changes.
// On page forms, changing Section updates the icon when it still matches the
// previous section default (or is blank).
export default class extends Controller {
  static targets = ["frame"]
  static values = {
    inputName: { type: String, default: "section[icon]" },
    sectionIcons: { type: Object, default: {} }
  }

  connect() {
    this.lastName = null
    this.trackedSectionDefault = this.normalize(this.iconInput?.value || "")
    this.sync({ force: false })
  }

  sync(eventOrOptions = {}) {
    const force = eventOrOptions === true || eventOrOptions?.force === true || eventOrOptions?.type === "input"
    const input = this.iconInput
    if (!input || !this.hasFrameTarget) return

    const name = this.normalize(input.value)
    const icon = this.iconElement
    if (!icon) return

    if (name === "") {
      icon.innerHTML = ""
      this.lastName = ""
      this.frameTarget.classList.add("opacity-40")
      return
    }

    this.frameTarget.classList.remove("opacity-40")

    // Initial paint: FlatPack's icon controller already fills the shell on connect.
    // Only rewrite when the typed name changes (or an input event forces a refresh).
    if (!force && this.lastName === null && this.hasDrawnPaths(icon)) {
      this.lastName = name
      return
    }

    if (!force && this.lastName === name && this.hasDrawnPaths(icon)) return

    this.lastName = name
    this.applyName(icon, name)
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

    if (stillOnPreviousDefault) {
      input.value = nextDefault
      this.trackedSectionDefault = nextDefault
      this.sync({ force: true })
    }
  }

  applyName(icon, name) {
    const iconController = this.application.getControllerForElementAndIdentifier(
      icon,
      "flat-pack--icon"
    )

    if (iconController) {
      // Stimulus skips nameValueChanged when the value is unchanged; nudge it so
      // #render runs after we need a refresh.
      if (iconController.nameValue === name) {
        iconController.nameValue = ""
      }
      iconController.nameValue = name
      return
    }

    icon.setAttribute("data-flat-pack--icon-name-value", name)
  }

  hasDrawnPaths(icon) {
    return icon.querySelector("path, circle, rect, line, polyline, polygon") != null
  }

  normalize(raw) {
    return raw.toString().trim().toLowerCase().replaceAll("_", "-")
  }

  get iconInput() {
    return this.element.querySelector(`input[name="${this.inputNameValue}"]`)
  }

  get iconElement() {
    return this.frameTarget.querySelector("[data-controller~='flat-pack--icon']")
  }
}
