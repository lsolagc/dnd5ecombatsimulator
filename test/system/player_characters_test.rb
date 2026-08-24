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

  test "should destroy Player character" do
    visit player_character_url(@player_character)
    accept_confirm { click_on "Excluir", match: :first }

    assert_text "Player character was successfully destroyed"
  end
end
