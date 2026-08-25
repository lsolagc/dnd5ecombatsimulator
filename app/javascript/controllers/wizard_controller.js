import { Controller } from "@hotwired/stimulus"

const ABILITIES = ["strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma"]
const FLAG_CYCLE = ["", "R", "I", "V"]

// Drives the 4-step character creation wizard (rail nav, ability steppers,
// R/I/V damage chips, offhand toggle, and the live RESUMO/Revisão preview).
// Nothing here persists on its own — it only prepares the single form that
// gets submitted for real on the last step.
export default class extends Controller {
  static targets = [
    "railItem", "panel", "backButton", "nextButton", "submitButton", "stepsRemaining",
    "nameInput", "levelInput", "classSelect", "armorClassInput", "maxHpOverrideInput",
    "abilityInput", "abilityModifier",
    "offhandName", "offhandField",
    "damageChip", "damageFlagInput", "featureGroup",
    "outName", "outClassLevel", "outHp", "outAc", "outAttacks"
  ]

  connect() {
    this.visited = [1]
    this.showStep(1)
    this.refreshAbilityModifiers()
    this.refreshDamageChips()
    this.toggleFeatureGroup()
    this.refreshPreview()
  }

  // --- step navigation ---

  next(event) {
    const step = this.currentStep() + 1
    if (step > this.panelTargets.length) return
    if (!this.visited.includes(step)) this.visited.push(step)
    this.showStep(step)
  }

  back() {
    this.showStep(Math.max(1, this.currentStep() - 1))
  }

  goTo(event) {
    const step = parseInt(event.currentTarget.dataset.step, 10)
    if (!this.visited.includes(step)) return
    this.showStep(step)
  }

  currentStep() {
    const visible = this.panelTargets.find((panel) => !panel.classList.contains("d-none"))
    return visible ? parseInt(visible.dataset.step, 10) : 1
  }

  showStep(step) {
    const lastStep = this.panelTargets.length

    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("d-none", parseInt(panel.dataset.step, 10) !== step)
    })
    this.railItemTargets.forEach((item) => {
      const itemStep = parseInt(item.dataset.step, 10)
      item.classList.toggle("active", itemStep === step)
      item.classList.toggle("wizard-step--visited", this.visited.includes(itemStep))
    })

    this.backButtonTarget.disabled = step === 1
    this.nextButtonTarget.classList.toggle("d-none", step === lastStep)
    this.submitButtonTarget.classList.toggle("d-none", step !== lastStep)
    this.stepsRemainingTarget.textContent = step === lastStep
      ? "Última etapa"
      : `${lastStep - step} de ${lastStep} etapas restantes`

    if (step === lastStep) this.refreshPreview()
  }

  // --- ability steppers ---

  incrementAbility(event) {
    this.stepAbility(event.currentTarget.dataset.ability, 1)
  }

  decrementAbility(event) {
    this.stepAbility(event.currentTarget.dataset.ability, -1)
  }

  stepAbility(ability, delta) {
    const input = this.abilityInputTargets.find((el) => el.dataset.ability === ability)
    if (!input) return
    const next = (parseInt(input.value, 10) || 0) + delta
    input.value = Math.min(30, Math.max(1, next))
    this.refreshAbilityModifiers()
    this.refreshPreview()
  }

  refreshAbilityModifiers() {
    ABILITIES.forEach((ability) => {
      const input = this.abilityInputTargets.find((el) => el.dataset.ability === ability)
      const label = this.abilityModifierTargets.find((el) => el.dataset.ability === ability)
      if (!input || !label) return
      label.textContent = this.formatModifier(this.modifierFor(input.value))
    })
  }

  modifierFor(score) {
    return Math.floor((parseInt(score, 10) - 10) / 2)
  }

  formatModifier(modifier) {
    return modifier >= 0 ? `+${modifier}` : `${modifier}`
  }

  abilityScore(ability) {
    const input = this.abilityInputTargets.find((el) => el.dataset.ability === ability)
    return input ? parseInt(input.value, 10) || 10 : 10
  }

  // --- R/I/V damage chips ---

  cycleFlag(event) {
    const type = event.currentTarget.dataset.damageType
    const input = this.damageFlagInputTargets.find((el) => el.dataset.damageType === type)
    if (!input) return
    const nextIndex = (FLAG_CYCLE.indexOf(input.value) + 1) % FLAG_CYCLE.length
    input.value = FLAG_CYCLE[nextIndex]
    this.refreshDamageChips()
  }

  refreshDamageChips() {
    this.damageChipTargets.forEach((chip) => {
      const type = chip.dataset.damageType
      const input = this.damageFlagInputTargets.find((el) => el.dataset.damageType === type)
      const value = input ? input.value : ""
      chip.querySelector("[data-wizard-chip-tag]").textContent = value || "—"
      chip.classList.toggle("wizard-chip--active", value !== "")
    })
  }

  // --- features step (read-only, filtered by the selected class) ---

  toggleFeatureGroup() {
    const classId = this.classSelectTarget.value
    this.featureGroupTargets.forEach((group) => {
      group.classList.toggle("d-none", group.dataset.playerClassId !== classId)
    })
  }

  // --- offhand weapon (visual only, not persisted) ---

  toggleOffhand() {
    const hasName = this.offhandNameTarget.value.trim().length > 0
    this.offhandFieldTargets.forEach((field) => { field.disabled = !hasName })
  }

  // --- live preview (RESUMO card + Revisão step) ---

  refreshPreview() {
    const name = this.nameInputTarget.value.trim() || "Sem nome"
    const level = parseInt(this.levelInputTarget.value, 10) || 1
    const option = this.classSelectTarget.selectedOptions[0]
    const className = option && option.value ? option.text : "Sem classe"
    const ac = this.armorClassInputTarget.value || "—"

    const progression = this.progressionFor(option, level)
    const attacks = progression ? progression.attacks_per_action : 1
    const hpOverride = parseInt(this.maxHpOverrideInputTarget.value, 10)
    const hp = hpOverride > 0 ? hpOverride : this.hpPreview(option, level)

    this.outNameTargets.forEach((el) => { el.textContent = name })
    this.outClassLevelTargets.forEach((el) => { el.textContent = `${className} · nível ${level}` })
    this.outHpTargets.forEach((el) => { el.textContent = hp })
    this.outAcTargets.forEach((el) => { el.textContent = ac })
    this.outAttacksTargets.forEach((el) => { el.textContent = attacks })
  }

  progressionFor(option, level) {
    if (!option || !option.dataset.progression) return null
    try {
      const rows = JSON.parse(option.dataset.progression)
      return rows.find((row) => row.level === level) || null
    } catch {
      return null
    }
  }

  hpPreview(option, level) {
    const hitDieValue = option ? parseInt(option.dataset.hitDieValue, 10) : null
    if (!hitDieValue) return "—"
    if (level === 1) return hitDieValue + this.modifierFor(this.abilityScore("constitution"))

    return "rolado ao salvar"
  }
}
