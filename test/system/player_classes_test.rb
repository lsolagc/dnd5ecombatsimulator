require "application_system_test_case"

class PlayerClassesTest < ApplicationSystemTestCase
  setup do
    @player_class = player_classes(:one)
  end

  test "visiting the index" do
    visit player_classes_url
    assert_selector "h1", text: "Player classes"
  end

  test "should create player class" do
    visit player_classes_url
    click_on "New player class"

    fill_in "Description", with: @player_class.description
    fill_in "Hit die", with: @player_class.hit_die
    fill_in "Name", with: @player_class.name
    fill_in "Spellcasting modifier", with: @player_class.spellcasting_modifier
    click_on "Create Player class"

    assert_text "Player class was successfully created"
    click_on "Back"
  end

  test "should update Player class" do
    visit player_class_url(@player_class)
    click_on "Edit this player class", match: :first

    fill_in "Description", with: @player_class.description
    fill_in "Hit die", with: @player_class.hit_die
    fill_in "Name", with: @player_class.name
    fill_in "Spellcasting modifier", with: @player_class.spellcasting_modifier
    click_on "Update Player class"

    assert_text "Player class was successfully updated"
    click_on "Back"
  end

  test "should destroy Player class" do
    visit player_class_url(@player_class)
    accept_confirm { click_on "Destroy this player class", match: :first }

    assert_text "Player class was successfully destroyed"
  end
end
