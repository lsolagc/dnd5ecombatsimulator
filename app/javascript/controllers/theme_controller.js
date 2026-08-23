import { Controller } from "@hotwired/stimulus"

// Segmented Claro/Escuro/Sistema control. Persists the raw preference in a
// cookie (read server-side on the next request) and resolves "system" via
// prefers-color-scheme on the client.
export default class extends Controller {
  static targets = ["option"]
  static values = { preference: String }

  connect() {
    this.highlight()
    this.apply(this.preferenceValue || "system")
  }

  choose(event) {
    const value = event.currentTarget.dataset.themeValue
    this.preferenceValue = value
    document.cookie = `theme=${value}; path=/; max-age=31536000; samesite=lax`
    this.highlight()
    this.apply(value)
  }

  apply(preference) {
    const resolved = preference === "system"
      ? (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
      : preference

    document.documentElement.setAttribute("data-bs-theme", resolved)
  }

  highlight() {
    this.optionTargets.forEach((option) => {
      option.classList.toggle("active", option.dataset.themeValue === this.preferenceValue)
    })
  }
}
