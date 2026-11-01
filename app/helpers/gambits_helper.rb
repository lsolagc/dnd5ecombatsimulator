module GambitsHelper
  # The action select's [label, action_choice] options: the character's gambit_actions, plus the gambit's own action
  # marked "(indisponível)" when the character lacks it. Looked up once per character per request.
  def gambit_action_options(character, gambit)
    @gambit_action_options_by_character ||= {}
    options = (@gambit_action_options_by_character[character.id] ||= character.gambit_actions.map { |action| [ action.action_label, action.action_choice ] })
    return options if gambit.action_kind.nil? || options.any? { |_, value| value == gambit.action_choice }

    options + [ [ "#{gambit.action_label} (indisponível)", gambit.action_choice ] ]
  end
end
