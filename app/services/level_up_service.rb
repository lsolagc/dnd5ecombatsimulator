class LevelUpService
  Result = Data.define(:player_character, :new_level, :proficiency_bonus, :can_improve_ability_scores)

  def initialize(player_character:)
    @player_character = player_character
  end

  def call
    @player_character.level_up!

    progression = @player_character.class_progression

    combatant = @player_character.combatant
    combatant.update!(proficiency_bonus: @player_character.proficiency_bonus)

    Result.new(
      player_character: @player_character,
      new_level: @player_character.level,
      proficiency_bonus: progression&.proficiency_bonus || @player_character.proficiency_bonus,
      can_improve_ability_scores: @player_character.can_improve_ability_scores?
    )
  end
end
