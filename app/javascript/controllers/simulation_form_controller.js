import { Controller } from "@hotwired/stimulus"

const DEFENSE_CYCLE = ["", "R", "I", "V"]
const DEFENSE_NAMES = { R: "resistente", I: "imune", V: "vulnerável" }

// Experiment builder: adds/removes combatant cards per side from server-rendered
// <template>s (one per character, a character can only be on one side), marks the
// fields edited away from the character sheet, and locks the count at 1 with a seed.
export default class extends Controller {
  static targets = ["seed", "count", "countHint", "template", "list", "picker", "card", "summary"]

  connect() {
    this.cardTargets.forEach((card) => this.refresh(card))
    this.toggleSeed()
    this.sync()
  }

  add(event) {
    const picker = event.currentTarget
    const template = this.templateTargets.find((t) => t.dataset.characterId === picker.value)
    picker.value = ""
    if (!template) return

    const card = template.content.firstElementChild.cloneNode(true)
    card.querySelector("[data-side-input]").value = picker.dataset.side
    this.listTargets.find((list) => list.dataset.side === picker.dataset.side).append(card)
    this.refresh(card)
    this.sync()
    card.querySelector("input:not([type=hidden])").focus()
  }

  remove(event) {
    event.currentTarget.closest(".sim-card").remove()
    this.sync()
  }

  reset(event) {
    const card = event.currentTarget.closest(".sim-card")
    card.querySelectorAll("[data-blueprint]").forEach((input) => { input.value = input.dataset.blueprint })
    this.refresh(card)
  }

  edited(event) {
    this.refresh(event.target.closest(".sim-card"))
  }

  cycleDefense(event) {
    const chip = event.currentTarget.closest(".sim-chip")
    const input = chip.querySelector("[data-defense-input]")
    input.value = DEFENSE_CYCLE[(DEFENSE_CYCLE.indexOf(input.value) + 1) % DEFENSE_CYCLE.length]
    this.refresh(chip.closest(".sim-card"))
  }

  toggleSeed() {
    const seeded = this.seedTarget.value.trim() !== ""
    if (seeded && !this.countTarget.disabled) {
      this.previousCount = this.countTarget.value
      this.countTarget.value = 1
    } else if (!seeded && this.countTarget.disabled) {
      this.countTarget.value = this.previousCount || 1
    }
    this.countTarget.disabled = seeded
    this.countHintTarget.textContent = seeded ? "Travado em 1 com seed." : this.countHintTarget.dataset.default
    this.summarize()
  }

  // Edited markers, the per-card edit count and the defenses summary line.
  refresh(card) {
    let edits = 0
    card.querySelectorAll("[data-blueprint]").forEach((input) => {
      const edited = input.value !== input.dataset.blueprint
      input.closest("[data-field]").classList.toggle("is-edited", edited)
      if (edited) edits++
    })

    const badge = card.querySelector("[data-edit-count]")
    badge.textContent = edits === 1 ? "1 ajuste" : `${edits} ajustes`
    badge.hidden = edits === 0
    card.querySelector("[data-reset-button]").hidden = edits === 0

    const active = []
    card.querySelectorAll(".sim-chip").forEach((chip) => {
      const flag = chip.querySelector("[data-defense-input]").value
      const button = chip.querySelector("button")
      chip.querySelector("[data-flag]").textContent = flag
      chip.classList.toggle("is-active", flag !== "")
      button.setAttribute("aria-label", `${button.dataset.label}: ${flag ? DEFENSE_NAMES[flag] : "normal"}`)
      if (flag) active.push(`${flag} ${button.dataset.label}`)
    })
    card.querySelector("[data-defense-summary]").textContent = active.length ? active.join(" · ") : "nenhuma"
  }

  // Keeps the pickers, side counters and run summary in step with the cards on the page.
  sync() {
    const chosen = new Set(this.cardTargets.map((card) => card.dataset.characterId))
    this.pickerTargets.forEach((picker) => {
      picker.querySelectorAll("option[value]:not([value=''])").forEach((option) => { option.disabled = chosen.has(option.value) })
    })
    this.listTargets.forEach((list) => {
      const count = list.querySelectorAll(".sim-card").length
      const label = this.element.querySelector(`[data-side-count="${list.dataset.side}"]`)
      label.textContent = count === 1 ? "1 combatente" : `${count} combatentes`
    })
    this.summarize()
  }

  summarize() {
    const [a, b] = this.listTargets.map((list) => list.querySelectorAll(".sim-card").length)
    const runs = parseInt(this.countTarget.value, 10) || 0
    const simulations = runs === 1 ? "1 simulação" : `${runs} simulações`
    this.summaryTarget.textContent = a && b ? `${a} contra ${b} · ${simulations}` : "Os dois lados precisam de pelo menos um combatente"
  }
}
