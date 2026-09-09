import { Controller } from "@hotwired/stimulus"

// Keeps the section form Heroicons preview in sync with the Icon field.
export default class extends Controller {
  static targets = ["frame"]

  connect() {
    this.lastName = null
    this.sync()
  }

  sync() {
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
    if (this.lastName === name && icon.innerHTML.length > 0) return

    this.lastName = name
    icon.innerHTML = ""

    const iconController = this.application.getControllerForElementAndIdentifier(
      icon,
      "flat-pack--icon"
    )

    if (iconController) {
      iconController.nameValue = name
      return
    }

    icon.setAttribute("data-flat-pack--icon-name-value", name)
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
