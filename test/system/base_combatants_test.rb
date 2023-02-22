require "application_system_test_case"

class BaseCombatantsTest < ApplicationSystemTestCase
  setup do
    @base_combatant = base_combatants(:one)
  end

  test "visiting the index" do
    visit base_combatants_url
    assert_selector "h1", text: "Base combatants"
  end

  test "should create base combatant" do
    visit base_combatants_url
    click_on "New base combatant"

    fill_in "Armor class", with: @base_combatant.armor_class
    fill_in "Charisma", with: @base_combatant.charisma
    fill_in "Constitution", with: @base_combatant.constitution
    fill_in "Dexterity", with: @base_combatant.dexterity
    fill_in "Hit dice number", with: @base_combatant.hit_dice_number
    fill_in "Hit die", with: @base_combatant.hit_die
    fill_in "Hitpoints", with: @base_combatant.hitpoints
    fill_in "Intelligence", with: @base_combatant.intelligence
    fill_in "Name", with: @base_combatant.name
    fill_in "Proficiency bonus", with: @base_combatant.proficiency_bonus
    fill_in "Skills", with: @base_combatant.skills
    fill_in "Strength", with: @base_combatant.strength
    fill_in "Wisdom", with: @base_combatant.wisdom
    click_on "Create Base combatant"

    assert_text "Base combatant was successfully created"
    click_on "Back"
  end

  test "should update Base combatant" do
    visit base_combatant_url(@base_combatant)
    click_on "Edit this base combatant", match: :first

    fill_in "Armor class", with: @base_combatant.armor_class
    fill_in "Charisma", with: @base_combatant.charisma
    fill_in "Constitution", with: @base_combatant.constitution
    fill_in "Dexterity", with: @base_combatant.dexterity
    fill_in "Hit dice number", with: @base_combatant.hit_dice_number
    fill_in "Hit die", with: @base_combatant.hit_die
    fill_in "Hitpoints", with: @base_combatant.hitpoints
    fill_in "Intelligence", with: @base_combatant.intelligence
    fill_in "Name", with: @base_combatant.name
    fill_in "Proficiency bonus", with: @base_combatant.proficiency_bonus
    fill_in "Skills", with: @base_combatant.skills
    fill_in "Strength", with: @base_combatant.strength
    fill_in "Wisdom", with: @base_combatant.wisdom
    click_on "Update Base combatant"

    assert_text "Base combatant was successfully updated"
    click_on "Back"
  end

  test "should destroy Base combatant" do
    visit base_combatant_url(@base_combatant)
    click_on "Destroy this base combatant", match: :first

    assert_text "Base combatant was successfully destroyed"
  end
end
