import { Controller } from "@hotwired/stimulus"

// Safety net for pushed updates: every few seconds, reloads the enclosing turbo-frame
// (refresh="morph", so it morphs in place) from the current page while this element
// is in it. The frame has no src in the page itself: Turbo rejects a frame whose src
// points at the page that contains it, so the first tick sets it.
export default class extends Controller {
  static values = { interval: { type: Number, default: 10000 } }

  connect() {
    this.timer = setInterval(() => {
      const frame = this.element.closest("turbo-frame")
      if (frame.src) frame.reload()
      else frame.src = window.location.href
    }, this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }
}
