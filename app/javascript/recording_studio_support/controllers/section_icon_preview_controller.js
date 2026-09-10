import { Controller } from "@hotwired/stimulus"

// Keeps the section form Heroicons preview in sync with the Icon field.
// FlatPack::Shared::IconComponent renders an empty SVG shell; flat-pack--icon
// fills the paths. Do not wipe those paths unless the name actually changes.
export default class extends Controller {
  static targets = ["frame"]

  connect() {
    this.lastName = null
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
    return this.element.querySelector('input[name="section[icon]"]')
  }

  get iconElement() {
    return this.frameTarget.querySelector("[data-controller~='flat-pack--icon']")
  }
}
