require "test_helper"

class PlayerCharactersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @player_character = player_characters(:aragorn)
  end

  test "should get index" do
    get player_characters_url
    assert_response :success
  end

  test "should get new" do
    get new_player_character_url
    assert_response :success
  end

  test "should create player_character" do
    assert_difference("PlayerCharacter.count") do
      post player_characters_url, params: { player_character: { level: @player_character.level, name: @player_character.name, player_class_id: @player_character.player_class_id, combatant: @player_character.combatant } }
    end

    assert_redirected_to player_character_url(PlayerCharacter.last)
  end

  test "should show player_character" do
    get player_character_url(@player_character)
    assert_response :success
  end

  test "should get edit" do
    get edit_player_character_url(@player_character)
    assert_response :success
  end

  test "should update player_character" do
    patch player_character_url(@player_character), params: { player_character: { level: @player_character.level, name: @player_character.name, player_class_id: @player_character.player_class_id } }
    assert_redirected_to player_character_url(@player_character)
  end

  test "should destroy player_character" do
    assert_difference("PlayerCharacter.count", -1) do
      delete player_character_url(@player_character)
    end

    assert_redirected_to player_characters_url
  end
end
