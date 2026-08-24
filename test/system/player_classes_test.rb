require "application_system_test_case"

class PlayerClassesTest < ApplicationSystemTestCase
  setup do
    @player_class = player_classes(:barbarian)
  end

  test "visiting the index" do
    visit player_classes_url
    assert_selector "h1", text: "Classes disponíveis"
  end

  test "should create player class" do
    @player_class.name = "New Class"

    visit player_classes_url
    click_on "Nova classe"

    fill_in "Descrição", with: @player_class.description
    select @player_class.hit_die, from: "Dado de vida"
    fill_in "Nome", with: @player_class.name
    select "Nenhuma", from: "Conjuração"
    click_on "Criar classe"

    assert_text "Player class was successfully created"
    click_on "Back to player classes"
  end

  test "should update Player class" do
    visit player_class_url(@player_class)
    click_on "Edit this player class", match: :first

    fill_in "Descrição", with: @player_class.description
    select @player_class.hit_die, from: "Dado de vida"
    fill_in "Nome", with: @player_class.name
    select "Nenhuma", from: "Conjuração"
    click_on "Salvar alterações"

    assert_text "Player class was successfully updated"
    click_on "Back to player classes"
  end

  test "should destroy Player class" do
    visit player_class_url(@player_class)
    accept_confirm { click_on "Destroy this player class", match: :first }

    assert_text "Player class was successfully destroyed"
  end
end
