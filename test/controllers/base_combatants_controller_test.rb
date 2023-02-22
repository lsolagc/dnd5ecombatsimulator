require "test_helper"

class BaseCombatantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @base_combatant = base_combatants(:one)
  end

  test "should get index" do
    get base_combatants_url
    assert_response :success
  end

  test "should get new" do
    get new_base_combatant_url
    assert_response :success
  end

  test "should create base_combatant" do
    assert_difference("BaseCombatant.count") do
      post base_combatants_url, params: { base_combatant: { armor_class: @base_combatant.armor_class, charisma: @base_combatant.charisma, constitution: @base_combatant.constitution, dexterity: @base_combatant.dexterity, hit_dice_number: @base_combatant.hit_dice_number, hit_die: @base_combatant.hit_die, hitpoints: @base_combatant.hitpoints, intelligence: @base_combatant.intelligence, name: @base_combatant.name, proficiency_bonus: @base_combatant.proficiency_bonus, skills: @base_combatant.skills, strength: @base_combatant.strength, wisdom: @base_combatant.wisdom } }
    end

    assert_redirected_to base_combatant_url(BaseCombatant.last)
  end

  test "should show base_combatant" do
    get base_combatant_url(@base_combatant)
    assert_response :success
  end

  test "should get edit" do
    get edit_base_combatant_url(@base_combatant)
    assert_response :success
  end

  test "should update base_combatant" do
    patch base_combatant_url(@base_combatant), params: { base_combatant: { armor_class: @base_combatant.armor_class, charisma: @base_combatant.charisma, constitution: @base_combatant.constitution, dexterity: @base_combatant.dexterity, hit_dice_number: @base_combatant.hit_dice_number, hit_die: @base_combatant.hit_die, hitpoints: @base_combatant.hitpoints, intelligence: @base_combatant.intelligence, name: @base_combatant.name, proficiency_bonus: @base_combatant.proficiency_bonus, skills: @base_combatant.skills, strength: @base_combatant.strength, wisdom: @base_combatant.wisdom } }
    assert_redirected_to base_combatant_url(@base_combatant)
  end

  test "should destroy base_combatant" do
    assert_difference("BaseCombatant.count", -1) do
      delete base_combatant_url(@base_combatant)
    end

    assert_redirected_to base_combatants_url
  end
end
