# A character's gambits screen: up to 6 FFXII-style rules, each slot saved on its own. Every action is
# scoped to the character, so another character's gambit is a 404.
class GambitsController < ApplicationController
  NO_RULES_TO_SAVE = "Este personagem está sem regras para salvar.".freeze

  before_action :set_player_character
  before_action :set_gambit, only: %i[ update toggle move destroy ]

  def index
    load_screen
  end

  def create
    @gambit = @player_character.add_gambit(gambit_params)

    if @gambit.persisted?
      redirect_to player_character_gambits_path(@player_character), status: :see_other, notice: "Gambit criado."
    else
      load_screen(new_gambit: @gambit)
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @gambit.update(gambit_params)
      redirect_to player_character_gambits_path(@player_character), status: :see_other, notice: "Gambit #{@gambit.position} salvo."
    else
      load_screen(invalid: @gambit)
      render :index, status: :unprocessable_entity
    end
  end

  def toggle
    @gambit.toggle!(:enabled)
    redirect_to player_character_gambits_path(@player_character), status: :see_other,
      notice: "Gambit #{@gambit.position} #{@gambit.enabled? ? "ligado" : "desligado"}."
  end

  # Swaps the gambit with its neighbor (direction=up|down); at either end nothing moves.
  def move
    return head :unprocessable_entity unless params[:direction].in?(%w[ up down ])

    @player_character.move_gambit(@gambit, params[:direction])
    redirect_to player_character_gambits_path(@player_character), status: :see_other
  end

  def destroy
    @player_character.remove_gambit(@gambit)
    redirect_to player_character_gambits_path(@player_character), status: :see_other, notice: "Gambit removido."
  end

  # ids[]: the character's gambit ids in their new order (drag and drop). Only an exact permutation of
  # them is accepted; any other shape of ids is a 422 too.
  def reorder
    ids = params[:ids]
    return head :unprocessable_entity unless ids.is_a?(Array) && ids.all? { |id| id.is_a?(String) && id.match?(/\A\d+\z/) }

    @player_character.reorder_gambits(ids.map(&:to_i)) ? head(:no_content) : head(:unprocessable_entity)
  end

  # Presets (GambitOwner#copy_gambits_from both ways). name: a new preset holding a copy of the character's rules.
  def save_preset
    name = params[:name] if params[:name].is_a?(String)
    preset = GambitPreset.new(name:)
    begin
      GambitPreset.transaction do
        raise ActiveRecord::Rollback unless preset.save && copy_character_gambits_into(preset)
      end
    rescue ActiveRecord::RecordNotUnique # another tab saved the same name after this one validated
      preset = GambitPreset.new(name:)
      preset.errors.add(:name, GambitPreset::NAME_TAKEN)
    rescue ActiveRecord::RecordInvalid => error
      return rule_refused(error.record, name:)
    end
    return preset_refused(preset.errors.map(&:message).to_sentence, name:) unless preset.persisted?

    preset_done(preset, "salvo")
  end

  # preset_id: an existing preset, replaced by a copy of the character's rules.
  def overwrite_preset
    preset = GambitPreset.find(params.expect(:preset_id))
    return preset_refused(NO_RULES_TO_SAVE) unless preset.copy_gambits_from(@player_character)

    preset_done(preset, "sobrescrito")
  rescue ActiveRecord::RecordInvalid => error
    rule_refused(error.record)
  end

  # preset_id: the character's rules are replaced by a copy of the preset's; a rule that does not hold at
  # the character's level refuses the whole preset.
  def apply_preset
    preset = GambitPreset.find(params.expect(:preset_id))
    return preset_refused("O preset #{preset.name} não tem regras") unless @player_character.copy_gambits_from(preset)

    preset_done(preset, "aplicado")
  rescue ActiveRecord::RecordInvalid => error
    rule_refused(error.record)
  end

  private

    def copy_character_gambits_into(preset)
      return true if preset.copy_gambits_from(@player_character)

      preset.errors.add(:base, NO_RULES_TO_SAVE)
      false
    end

    def preset_done(preset, verb)
      redirect_to player_character_gambits_path(@player_character), status: :see_other, notice: "Preset #{preset.name} #{verb}."
    end

    # A copied rule that does not hold where it lands (copy_gambits_from changed nothing): a character's
    # rules are checked at its level, a preset's at the feature's highest.
    def rule_refused(rule, name: nil)
      owner = rule.owner
      destination = owner.is_a?(PlayerCharacter) ? "#{owner.name} no nível #{owner.level}" : "o preset #{owner.name}"
      preset_refused("Nada foi alterado: a regra #{rule.position} (#{rule.label}) não vale para #{destination}. " \
                     "#{rule.errors.map(&:message).to_sentence}.", name:)
    end

    # The screen again (422) with the error in the presets panel; name refills the new preset's field.
    def preset_refused(message, name: nil)
      load_screen
      @preset_error = message
      @preset_name = name
      render :index, status: :unprocessable_entity
    end

    def set_player_character
      @player_character = PlayerCharacter.find(params.expect(:player_character_id))
    end

    def set_gambit
      @gambit = @player_character.gambits.find(params.expect(:id))
    end

    # The action arrives as one select value (Gambit#action_choice): "attack", "class_feature:ID" or "spell:ID".
    def gambit_params
      attributes = params.expect(gambit: %i[ target condition condition_value action ])
      kind, id = attributes.delete(:action).to_s.split(":", 2)
      kind = nil unless kind.in?(Gambit.action_kinds.keys)
      # A condition without a value clears the stored one (the screen disables the hidden field, so it is not sent).
      attributes[:condition_value] = nil if attributes.key?(:condition) && !attributes[:condition].in?(Gambit::CONDITIONS_WITH_VALUE)
      attributes.merge(
        action_kind: kind,
        class_feature_id: (id if kind == "class_feature"),
        spell_id: (id if kind == "spell")
      )
    end

    # invalid: a slot that failed to save, shown with its errors in place of the stored rule.
    def load_screen(new_gambit: nil, invalid: nil)
      @gambits = @player_character.gambits.includes(:class_feature, :spell).map { |gambit| gambit == invalid ? invalid : gambit }
      @new_gambit = new_gambit || Gambit.new(target: :enemy, condition: :any, action_kind: :attack)
      @presets = GambitPreset.includes(:gambits).order(:name)
    end
end
