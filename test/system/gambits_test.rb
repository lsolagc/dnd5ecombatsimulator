require "application_system_test_case"

class GambitsTest < ApplicationSystemTestCase
  include ActionView::RecordIdentifier

  setup do
    @thorin = player_characters(:thorin) # level 5: Ataque, Second Wind and Action Surge
  end

  test "build, edit, toggle and reorder the rules; dragging persists and changes who fires first" do
    visit player_character_url(@thorin)
    assert_text "Sem gambits: ação aleatória"
    click_on "Gambits"

    assert_selector "h1", text: "Gambits de Thorin"
    assert_text "avaliadas de cima para baixo"
    assert_selector "#new_gambit", text: /novo gambit/i
    assert_selector "li", text: "vazio", count: 5
    within("#new_gambit") { assert_no_field "Valor" } # "Qualquer" takes no value: hidden by Stimulus
    page.save_screenshot(Rails.root.join("tmp/screenshots/gambits-empty.png"))

    add_rule(target: "Inimigo", condition: "Qualquer", action: "Ataque")
    add_rule(target: "Inimigo", condition: "Menor HP", action: "Ataque")
    assert_equal [ [ 1, "Inimigo: qualquer → Ataque" ], [ 2, "Inimigo: menor HP → Ataque" ] ], rules
    first_rule, second_rule = @thorin.gambits.reload.to_a

    # Edit rule 2: target, condition with a value, action.
    within("##{dom_id(second_rule)}") do
      select "Self", from: "Alvo"
      select "Recurso no mínimo", from: "Condição"
      fill_in "Valor", with: "1"
      select "Second Wind", from: "Ação"
      click_on "Salvar"
    end
    assert_text "Gambit 2 salvo."
    assert_equal [ [ 1, "Inimigo: qualquer → Ataque" ], [ 2, "Self: recurso ≥ 1 → Second Wind" ] ], rules

    # On/off.
    within("##{dom_id(second_rule)}") { find("[role=switch]").click }
    assert_text "Gambit 2 desligado."
    assert_not second_rule.reload.enabled?
    within("##{dom_id(second_rule)}") { find("[role=switch]", text: "Desligado").click }
    assert_text "Gambit 2 ligado."
    assert second_rule.reload.enabled?

    # Up/down buttons, disabled at the ends.
    within("##{dom_id(first_rule)}") { assert_button "Subir regra 1", disabled: true }
    within("##{dom_id(second_rule)}") { assert_button "Descer regra 2", disabled: true }
    within("##{dom_id(first_rule)}") { click_on "Descer regra 1" }
    assert_selector "[data-gambits-target=slot]:first-child##{dom_id(second_rule)}"
    assert_equal [ second_rule.id, first_rule.id ], @thorin.gambits.reload.map(&:id)
    within("##{dom_id(first_rule)}") { click_on "Subir regra 2" }
    assert_selector "[data-gambits-target=slot]:first-child##{dom_id(first_rule)}"
    assert_equal [ [ 1, "Inimigo: qualquer → Ataque" ], [ 2, "Self: recurso ≥ 1 → Second Wind" ] ], rules
    page.save_screenshot(Rails.root.join("tmp/screenshots/gambits-rules.png"))

    assert_equal({ type: :attack }, first_decision.slice(:type), "rule 1 (Ataque) decides the turn before the drag")

    # Drag rule 2 onto rule 1 (native HTML5 DnD, emulated by Capybara's Selenium drag_to).
    find("##{dom_id(second_rule)} [draggable=true]").drag_to(find("##{dom_id(first_rule)}"))
    assert_selector "[data-gambits-target=slot]:first-child##{dom_id(second_rule)}", text: "1"
    assert_equal [ [ 1, "Self: recurso ≥ 1 → Second Wind" ], [ 2, "Inimigo: qualquer → Ataque" ] ], rules

    assert_equal({ type: :class_feature, feature_slug: "second-wind" }, first_decision.slice(:type, :feature_slug),
      "after the drag, the rule now on top (Second Wind) decides the turn")
    page.save_screenshot(Rails.root.join("tmp/screenshots/gambits-dragged.png"))

    # Drag down: rule 1 onto rule 2 takes its place.
    find("##{dom_id(second_rule)} [draggable=true]").drag_to(find("##{dom_id(first_rule)}"))
    assert_selector "[data-gambits-target=slot]:first-child##{dom_id(first_rule)}", text: "1"
    assert_equal [ [ 1, "Inimigo: qualquer → Ataque" ], [ 2, "Self: recurso ≥ 1 → Second Wind" ] ], rules

    click_on "Voltar para a ficha"
    within("#gambits_summary") do
      assert_text "1 Inimigo: qualquer → Ataque"
      assert_text "2 Self: recurso ≥ 1 → Second Wind"
    end
  end

  test "switching a rule from a condition with a value to one without saves" do
    gambit = Gambit.create!(owner: @thorin, position: 1, target: :enemy, condition: :hp_below, condition_value: 40, action_kind: :attack)
    visit player_character_gambits_url(@thorin)

    within("##{dom_id(gambit)}") do
      assert_field "Valor", with: "40"
      select "Qualquer", from: "Condição"
      assert_no_field "Valor"
      click_on "Salvar"
    end

    assert_text "Gambit 1 salvo."
    assert_equal [ "any", nil ], gambit.reload.values_at(:condition, :condition_value)
  end

  test "an invalid combination shows the error in its slot; a disabled rule is dimmed on the sheet" do
    gambit = Gambit.create!(owner: @thorin, position: 1, target: :enemy, condition: :any, action_kind: :attack, enabled: false)
    visit player_character_gambits_url(@thorin)

    within("##{dom_id(gambit)}") do
      select "Self", from: "Alvo"
      click_on "Salvar"
      assert_selector ".alert-danger", text: "O alvo não combina com a ação (ela mira Inimigo)"
      assert has_select?("Alvo", selected: "Self")
    end
    page.save_screenshot(Rails.root.join("tmp/screenshots/gambits-error.png"))
    assert gambit.reload.target_enemy?

    visit player_character_url(@thorin)
    assert_selector "#gambits_summary li.opacity-50", text: "Inimigo: qualquer → Ataque (desligado)"
    assert_text "Todos desligados: ação aleatória."
  end

  test "with 6 rules there is no new gambit form, and a rule whose action the character lacks is marked unavailable" do
    6.times { |index| Gambit.create!(owner: @thorin, position: index + 1, target: :enemy, condition: :any, action_kind: :attack) }
    foreign_spell = Gambit.find_by!(owner: @thorin, position: 6)
    foreign_spell.update!(action_kind: :spell, spell: spells(:fire_bolt))

    visit player_character_gambits_url(@thorin)

    assert_selector "[data-gambits-target=slot]", count: 6
    assert_no_selector "#new_gambit"
    assert_no_text "vazio"
    within("##{dom_id(foreign_spell)}") { assert has_select?("Ação", selected: "Fire Bolt (indisponível)") }
    page.save_screenshot(Rails.root.join("tmp/screenshots/gambits-full.png"))
  end

  private

    def add_rule(target:, condition:, action:)
      within("#new_gambit") do
        select target, from: "Alvo"
        select condition, from: "Condição"
        select action, from: "Ação"
        click_on "Adicionar"
      end
      assert_text "Gambit criado."
    end

    # [position, label] of Thorin's stored rules, by position.
    def rules
      @thorin.gambits.reload.map { |gambit| [ gambit.position, gambit.label ] }
    end

    # Thorin's first decision in a one-round fight, with the rule that drove it.
    def first_decision
      thorin = PlayerCharacter.find(@thorin.id)
      result = Combat::Simulator.new(party_one: [ thorin ], party_two: [ player_characters(:aragorn) ], seed: 1, max_rounds: 1).call
      turn = result[:round_log].flat_map { |round| round[:turns] }
        .find { |entry| entry[:actor_id] == thorin.id && entry.dig(:action, :type) != :turn_passive }
      assert_equal 1, turn.dig(:gambit, :position), "not driven by the rule in position 1"
      turn[:action]
    end
end
