require "application_system_test_case"

class GambitPresetsTest < ApplicationSystemTestCase
  include ActionView::RecordIdentifier

  setup do
    @a = player_characters(:thorin)       # level 5: Ataque, Second Wind, Action Surge
    @b = player_characters(:aragorn)      # level 1: no Action Surge
    @c = player_characters(:aragorn_copy)
  end

  test "save A as a preset, apply it to B, adjust B, overwrite from A: copies both ways, no live link" do
    # B starts with a rule of its own, which applying must replace.
    b_own = Gambit.create!(owner: @b, position: 1, target: :enemy, condition: :marked, action_kind: :attack)

    # 1. Build A's rules on the screen and save them as a new preset.
    visit player_character_gambits_url(@a)
    within("#presets") do
      assert_text "Nenhum preset salvo ainda", count: 2
      assert_no_button "Sobrescrever"
      assert_no_button "Aplicar"
    end
    page.save_screenshot(Rails.root.join("tmp/screenshots/presets-empty.png"))

    add_rule(target: "Inimigo", condition: "Menor HP", action: "Ataque")
    add_rule(target: "Self", condition: "HP abaixo de (%)", value: "50", action: "Second Wind")
    add_rule(target: "Self", condition: "Qualquer", action: "Action Surge")
    a_rules = [ [ 1, true, "Inimigo: menor HP → Ataque" ], [ 2, true, "Self: HP < 50% → Second Wind" ], [ 3, true, "Self: qualquer → Action Surge" ] ]
    assert_equal a_rules, rows(@a)

    within("#save_preset") do
      fill_in "Nome do novo preset", with: "Tanque"
      click_on "Salvar como novo"
    end
    assert_text "Preset Tanque salvo."
    preset = GambitPreset.find_by!(name: "Tanque")
    assert_equal a_rules, rows(preset)
    within("#apply_preset") { assert has_select?("Preset a aplicar", options: [ "Tanque (3 regras)" ]) }
    page.save_screenshot(Rails.root.join("tmp/screenshots/presets-saved.png"))

    # 2. On B's screen, apply the preset: B's rules become the preset's (as new rows).
    visit player_character_gambits_url(@b)
    within("#apply_preset") do
      select "Tanque (3 regras)", from: "Preset a aplicar"
      accept_confirm(/substitui as regras atuais de Aragorn \(1 regra\)/) { click_on "Aplicar" }
    end
    assert_text "Preset Tanque aplicado."
    assert_equal a_rules, rows(@b)
    assert_not Gambit.exists?(b_own.id)
    assert_empty Gambit.where(owner: @b).ids & Gambit.where(owner: preset).ids, "B must not share rows with the preset"
    assert_equal a_rules, rows(preset), "applying leaves the preset as it was"
    surge = Gambit.find_by!(owner: @b, position: 3)
    within("##{dom_id(surge)}") { assert has_select?("Ação", selected: "Action Surge (indisponível)") }
    page.save_screenshot(Rails.root.join("tmp/screenshots/presets-applied.png"))

    # 3. Adjust B (toggle, edit, remove): the preset does not change, and applying it to C still gives A's rules.
    first, second = Gambit.where(owner: @b).order(:position).to_a
    within("##{dom_id(first)}") { find("[role=switch]").click }
    assert_text "Gambit 1 desligado."
    within("##{dom_id(second)}") do
      fill_in "Valor", with: "20"
      click_on "Salvar"
    end
    assert_text "Gambit 2 salvo."
    within("##{dom_id(surge)}") { click_on "Remover" }
    assert_text "Gambit removido."
    b_rules = [ [ 1, false, "Inimigo: menor HP → Ataque" ], [ 2, true, "Self: HP < 20% → Second Wind" ] ]
    assert_equal b_rules, rows(@b)
    assert_equal a_rules, rows(preset), "adjusting B changed the preset"

    visit player_character_gambits_url(@c)
    within("#apply_preset") do
      select "Tanque (3 regras)", from: "Preset a aplicar"
      accept_confirm { click_on "Aplicar" }
    end
    assert_text "Preset Tanque aplicado."
    assert_equal a_rules, rows(@c)

    # 4. Change A, overwrite the preset from A: the preset follows A, B keeps its own rules.
    visit player_character_gambits_url(@a)
    a_first = Gambit.find_by!(owner: @a, position: 1)
    within("##{dom_id(a_first)}") { click_on "Remover" }
    assert_text "Gambit removido."
    add_rule(target: "Inimigo", condition: "Maior HP", action: "Ataque")
    new_a_rules = [ [ 1, true, "Self: HP < 50% → Second Wind" ], [ 2, true, "Self: qualquer → Action Surge" ], [ 3, true, "Inimigo: maior HP → Ataque" ] ]
    assert_equal new_a_rules, rows(@a)

    # A duplicate name (other case) is refused on the screen.
    within("#save_preset") do
      fill_in "Nome do novo preset", with: "tanque"
      click_on "Salvar como novo"
    end
    within("#preset_errors") { assert_text "Já existe um preset com esse nome" }
    assert_equal 1, GambitPreset.count

    within("#save_preset") do
      select "Tanque (3 regras)", from: "Preset a sobrescrever"
      accept_confirm(/com as regras de Thorin \(3 regras\)/) { click_on "Sobrescrever" }
    end
    assert_text "Preset Tanque sobrescrito."
    assert_equal new_a_rules, rows(preset.reload)
    assert_equal b_rules, rows(@b), "overwriting the preset changed B"
    assert_equal a_rules, rows(@c), "overwriting the preset changed C"
    page.save_screenshot(Rails.root.join("tmp/screenshots/presets-overwritten.png"))
  end

  private

    def add_rule(target:, condition:, action:, value: nil)
      within("#new_gambit") do
        select target, from: "Alvo"
        select condition, from: "Condição"
        fill_in "Valor", with: value if value
        select action, from: "Ação"
        click_on "Adicionar"
      end
      assert_text "Gambit criado."
    end

    # [position, enabled, label] of an owner's stored rules, read from the database.
    def rows(owner)
      Gambit.where(owner:).order(:position).map { |gambit| [ gambit.position, gambit.enabled, gambit.label ] }
    end
end
