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

  test "should update Player character" do
    visit player_character_url(@player_character)
    click_on "Editar", match: :first

    fill_in "Level", with: @player_character.level
    fill_in "Name", with: @player_character.name
    fill_in "Player class", with: @player_character.player_class_id
    click_on "Update Player character"

    assert_text "Player character was successfully updated"
    click_on "Voltar para personagens"
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

  test "editing HP máximo persists on the associated combatant across a reload" do
    visit edit_player_character_url(@player_character)

    fill_in "HP máximo", with: "77"
    page.save_screenshot(Rails.root.join("tmp/screenshots/edit_hp_field.png"))
    click_on "Update Player character"

    assert_text "Player character was successfully updated"
    assert_equal 77, PlayerCharacter.includes(:combatant).find(@player_character.id).max_hit_points
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

  test "invalid HP máximo blocks saving and shows a visible error on the edit form" do
    visit edit_player_character_url(@player_character)

    fill_in "HP máximo", with: "-5"
    click_on "Update Player character"

    assert_selector "#error_explanation"
    page.save_screenshot(Rails.root.join("tmp/screenshots/edit_hp_field_invalid.png"))
  end

  test "should destroy Player character" do
    visit player_character_url(@player_character)
    accept_confirm { click_on "Excluir", match: :first }

    assert_text "Player character was successfully destroyed"
  end
end
