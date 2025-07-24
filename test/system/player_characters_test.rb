require "application_system_test_case"

class PlayerCharactersTest < ApplicationSystemTestCase
  setup do
    @player_character = player_characters(:one)
  end

  test "visiting the index" do
    visit player_characters_url
    assert_selector "h1", text: "Player characters"
  end

  test "should create player character" do
    visit player_characters_url
    click_on "New player character"

    fill_in "Level", with: @player_character.level
    fill_in "Name", with: @player_character.name
    fill_in "Player class", with: @player_character.player_class_id
    click_on "Create Player character"

    assert_text "Player character was successfully created"
    click_on "Back"
  end

  test "should update Player character" do
    visit player_character_url(@player_character)
    click_on "Edit this player character", match: :first

    fill_in "Level", with: @player_character.level
    fill_in "Name", with: @player_character.name
    fill_in "Player class", with: @player_character.player_class_id
    click_on "Update Player character"

    assert_text "Player character was successfully updated"
    click_on "Back"
  end

  test "should destroy Player character" do
    visit player_character_url(@player_character)
    accept_confirm { click_on "Destroy this player character", match: :first }

    assert_text "Player character was successfully destroyed"
  end
end
