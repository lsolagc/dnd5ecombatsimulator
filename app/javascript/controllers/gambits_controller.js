import { Controller } from "@hotwired/stimulus"

// Gambits screen: native HTML5 drag and drop of the filled slots (dropping a slot on another takes its
// place, then the new id order is PATCHed to reorder and the page reloads with the new positions), and
// the condition value field shown only for conditions that take a value.
export default class extends Controller {
  static targets = ["slot", "condition", "value"]
  static values = { reorderUrl: String }

  connect() {
    this.conditionTargets.forEach(select => this.toggleValue(select))
  }

  syncValue(event) {
    this.toggleValue(event.target)
  }

  // Disabled while hidden, so a stale number is not submitted with a condition that takes none.
  toggleValue(select) {
    const takesValue = select.selectedOptions[0]?.dataset.takesValue === "true"
    const field = this.valueTargets.find(target => target.closest("form") === select.form)
    field.classList.toggle("d-none", !takesValue)
    field.querySelector("input").disabled = !takesValue
  }

  dragstart(event) {
    this.dragged = event.target.closest("[data-gambits-target='slot']")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.dragged.dataset.id)
    event.dataTransfer.setDragImage(this.dragged, 0, 0)
  }

  dragover(event) {
    if (this.dragged) event.preventDefault()
  }

  dragend() {
    this.dragged = null
  }

  async drop(event) {
    const target = event.currentTarget
    if (!this.dragged) return
    event.preventDefault()
    const dragged = this.dragged
    this.dragged = null
    if (target === dragged) return

    const movingDown = this.slotTargets.indexOf(dragged) < this.slotTargets.indexOf(target)
    target.parentNode.insertBefore(dragged, movingDown ? target.nextSibling : target)

    const body = new FormData()
    this.slotTargets.forEach(slot => body.append("ids[]", slot.dataset.id))
    // Reloads either way: on success with the new positions, on a refusal with the stored order.
    await fetch(this.reorderUrlValue, {
      method: "PATCH",
      body,
      headers: { "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content }
    })
    window.Turbo.visit(window.location.href, { action: "replace" })
  }
}
