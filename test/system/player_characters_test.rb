require "application_system_test_case"

class PlayerCharactersTest < ApplicationSystemTestCase
  setup do
    @player_character = player_characters(:aragorn)
  end

  test "visiting the index" do
    visit player_characters_url
    assert_selector "h1", text: "Personagens"
  end

  test "should create player character" do
    visit player_characters_url
    click_on "Novo personagem"

    fill_in "Identificação do combatente", with: "Gimli"
    select @player_character.player_class.name, from: "Classe"
    fill_in "Nível", with: @player_character.level

    click_on "Continuar"
    click_on "Continuar"
    click_on "Continuar"
    click_on "Criar personagem"

    assert_text "Player character was successfully created"
  end

  test "editing pre-fills every wizard step with the character's current values" do
    @player_character.combatant.update!(
      immunities: @player_character.combatant.immunities.deep_merge("damage_types" => { "poison" => true })
    )

    visit player_character_url(@player_character)
    click_on "Editar", match: :first

    assert_field "Identificação do combatente", with: @player_character.name
    assert_field "Nível", with: @player_character.level.to_s
    assert page.has_select?("Classe", selected: @player_character.player_class.name)
    assert_equal @player_character.strength.to_s,
      find("[data-wizard-target='abilityInput'][data-ability='strength']").value
    page.save_screenshot(Rails.root.join("tmp/screenshots/edit_prefilled_step1.png"))

    find("[data-wizard-target='railItem'][data-step='2']").click
    assert_field "Classe de armadura", with: @player_character.armor_class.to_s
    assert_field "Deslocamento (ft)", with: @player_character.combatant.speed.to_s
    assert_field "HP máximo (opcional — substitui o cálculo automático)", with: @player_character.max_hit_points.to_s
    poison_chip = find("[data-wizard-target='damageChip'][data-damage-type='poison']")
    assert_equal "I", poison_chip.find("[data-wizard-chip-tag]").text
    assert_selector "[data-wizard-target='damageChip'][data-damage-type='poison'].wizard-chip--active"
    page.save_screenshot(Rails.root.join("tmp/screenshots/edit_prefilled_step2.png"))
  end

  test "changing class while editing clears the stale HP override so it recalculates" do
    visit edit_player_character_url(@player_character)
    find("[data-wizard-target='railItem'][data-step='2']").click
    assert_field "HP máximo (opcional — substitui o cálculo automático)", with: @player_character.max_hit_points.to_s

    find("[data-wizard-target='railItem'][data-step='1']").click
    select player_classes(:wizard).name, from: "Classe"

    find("[data-wizard-target='railItem'][data-step='2']").click
    assert_field "HP máximo (opcional — substitui o cálculo automático)", with: ""

    find("[data-wizard-target='railItem'][data-step='4']").click
    assert_selector "[data-wizard-target='outHp']", text: "8", minimum: 1
  end

  test "editing allows jumping directly between steps out of order" do
    visit edit_player_character_url(@player_character)

    find("[data-wizard-target='railItem'][data-step='4']").click
    assert_selector "[data-wizard-target='panel'][data-step='4']:not(.d-none)"
    assert_text "Revisão"
    page.save_screenshot(Rails.root.join("tmp/screenshots/edit_free_navigation_step4.png"))

    find("[data-wizard-target='railItem'][data-step='1']").click
    assert_selector "[data-wizard-target='panel'][data-step='1']:not(.d-none)"
  end

  test "editing an attribute, a resistance chip, and HP persists the changes" do
    visit edit_player_character_url(@player_character)

    find("[data-wizard-target='abilityInput'][data-ability='strength']").set(18)

    find("[data-wizard-target='railItem'][data-step='2']").click
    fill_in "HP máximo (opcional — substitui o cálculo automático)", with: "77"
    find("[data-wizard-target='damageChip'][data-damage-type='fire']").click
    page.save_screenshot(Rails.root.join("tmp/screenshots/edit_step2_edited.png"))

    find("[data-wizard-target='railItem'][data-step='4']").click
    click_on "Salvar alterações"

    assert_text "Player character was successfully updated"
    reloaded = PlayerCharacter.includes(:combatant).find(@player_character.id)
    assert_equal 18, reloaded.strength
    assert_equal 77, reloaded.max_hit_points
    assert reloaded.resistant_to?(damage_type: "fire")
  end

  test "saving the edit wizard without changing anything does not alter the character" do
    original_character_attrs = @player_character.attributes.except("updated_at")
    original_combatant_attrs = @player_character.combatant.attributes.except("updated_at")

    visit edit_player_character_url(@player_character)
    find("[data-wizard-target='railItem'][data-step='4']").click
    click_on "Salvar alterações"

    assert_text "Player character was successfully updated"
    reloaded = PlayerCharacter.includes(:combatant).find(@player_character.id)
    assert_equal original_character_attrs, reloaded.attributes.except("updated_at")
    assert_equal original_combatant_attrs, reloaded.combatant.attributes.except("updated_at")
  end

  test "wizard HP override updates the Revisão preview and is persisted exactly on create" do
    visit new_player_character_url
    fill_in "Identificação do combatente", with: "Gimli"
    select @player_character.player_class.name, from: "Classe"
    fill_in "Nível", with: 1

    click_on "Continuar"
    fill_in "HP máximo (opcional — substitui o cálculo automático)", with: "50"
    page.save_screenshot(Rails.root.join("tmp/screenshots/wizard_hp_override_combat_step.png"))

    click_on "Continuar"
    click_on "Continuar"
    assert_selector "[data-wizard-target='outHp']", text: "50", count: 2
    page.save_screenshot(Rails.root.join("tmp/screenshots/wizard_hp_override_review_step.png"))

    click_on "Criar personagem"

    assert_text "Player character was successfully created"
    assert_equal 50, PlayerCharacter.order(:created_at).last.reload.max_hit_points
    page.save_screenshot(Rails.root.join("tmp/screenshots/wizard_hp_override_show.png"))
  end

  test "wizard without HP override keeps the automatic calculation on create" do
    visit new_player_character_url
    fill_in "Identificação do combatente", with: "Legolas"
    select @player_character.player_class.name, from: "Classe"
    fill_in "Nível", with: 1

    click_on "Continuar"
    click_on "Continuar"
    click_on "Continuar"
    assert_no_selector "[data-wizard-target='outHp']", text: "—"
    page.save_screenshot(Rails.root.join("tmp/screenshots/wizard_hp_auto_review_step.png"))

    click_on "Criar personagem"

    assert_text "Player character was successfully created"
    created = PlayerCharacter.order(:created_at).last.reload
    assert_equal created.hit_points_at_level_one, created.max_hit_points
  end

  test "invalid HP máximo blocks saving and shows a visible error on the wizard" do
    visit new_player_character_url
    fill_in "Identificação do combatente", with: "Bad HP"
    select @player_character.player_class.name, from: "Classe"
    fill_in "Nível", with: 1

    click_on "Continuar"
    fill_in "HP máximo (opcional — substitui o cálculo automático)", with: "0"
    click_on "Continuar"
    click_on "Continuar"
    click_on "Criar personagem"

    assert_text "impediram a criação do personagem"
    assert_text "Max hit points input"
    page.save_screenshot(Rails.root.join("tmp/screenshots/wizard_hp_override_invalid.png"))
  end

  test "invalid HP máximo blocks saving and shows a visible error on the edit wizard" do
    visit edit_player_character_url(@player_character)

    find("[data-wizard-target='railItem'][data-step='2']").click
    fill_in "HP máximo (opcional — substitui o cálculo automático)", with: "-5"
    find("[data-wizard-target='railItem'][data-step='4']").click
    click_on "Salvar alterações"

    assert_selector "#error_explanation"
    page.save_screenshot(Rails.root.join("tmp/screenshots/edit_hp_field_invalid.png"))
  end

  test "should destroy Player character" do
    visit player_character_url(@player_character)
    accept_confirm { click_on "Excluir", match: :first }

    assert_text "Player character was successfully destroyed"
  end
end
