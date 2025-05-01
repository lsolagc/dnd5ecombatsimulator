require "test_helper"

class PlayerClassesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @player_class = player_classes(:one)
  end

  test "should get index" do
    get player_classes_url
    assert_response :success
  end

  test "should get new" do
    get new_player_class_url
    assert_response :success
  end

  test "should create player_class" do
    assert_difference("PlayerClass.count") do
      post player_classes_url, params: { player_class: { description: @player_class.description, hit_die: @player_class.hit_die, name: @player_class.name, spellcasting_modifier: @player_class.spellcasting_modifier } }
    end

    assert_redirected_to player_class_url(PlayerClass.last)
  end

  test "should show player_class" do
    get player_class_url(@player_class)
    assert_response :success
  end

  test "should get edit" do
    get edit_player_class_url(@player_class)
    assert_response :success
  end

  test "should update player_class" do
    patch player_class_url(@player_class), params: { player_class: { description: @player_class.description, hit_die: @player_class.hit_die, name: @player_class.name, spellcasting_modifier: @player_class.spellcasting_modifier } }
    assert_redirected_to player_class_url(@player_class)
  end

  test "should destroy player_class" do
    assert_difference("PlayerClass.count", -1) do
      delete player_class_url(@player_class)
    end

    assert_redirected_to player_classes_url
  end
end
