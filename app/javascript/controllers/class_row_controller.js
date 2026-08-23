import { Controller } from "@hotwired/stimulus"

// One controller instance per <tbody> in the player_classes table: toggles
// the expanded progression/features row and its chevron.
export default class extends Controller {
  static targets = ["detail", "chevron"]

  toggle() {
    const isHidden = this.detailTarget.classList.toggle("d-none")
    this.chevronTarget.textContent = isHidden ? "▸" : "▾"
    this.chevronTarget.classList.toggle("text-primary", !isHidden)
  }
}
