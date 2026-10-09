# A character's gambits screen: up to 6 FFXII-style rules, each slot saved on its own. Every action is
# scoped to the character, so another character's gambit is a 404.
class GambitsController < ApplicationController
  before_action :set_player_character
  before_action :set_gambit, only: %i[ update toggle move destroy ]

  def index
    load_screen
  end

  def create
    saved = with_character_locked do
      @gambit = Gambit.new(gambit_params.merge(owner: @player_character, position: @player_character.gambits.count + 1))
      @gambit.save
    end

    if saved
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

    with_character_locked do
      gambits = @player_character.gambits.to_a
      index = gambits.index(@gambit)
      other = params[:direction] == "up" ? index - 1 : index + 1
      if other.between?(0, gambits.size - 1)
        gambits[index], gambits[other] = gambits[other], gambits[index]
        rewrite_positions(gambits)
      end
    end

    redirect_to player_character_gambits_path(@player_character), status: :see_other
  end

  def destroy
    with_character_locked do
      @gambit.destroy!
      rewrite_positions(@player_character.gambits.reload)
    end

    redirect_to player_character_gambits_path(@player_character), status: :see_other, notice: "Gambit removido."
  end

  # ids[]: the character's gambit ids in their new order (drag and drop). Only an exact permutation of
  # them is accepted; any other shape of ids is a 422 too.
  def reorder
    ids = params[:ids]
    return head :unprocessable_entity unless ids.is_a?(Array) && ids.all? { |id| id.is_a?(String) && id.match?(/\A\d+\z/) }

    accepted = with_character_locked do
      gambits = @player_character.gambits.index_by(&:id)
      ids = ids.map(&:to_i)
      ids.sort == gambits.keys.sort && rewrite_positions(gambits.values_at(*ids))
    end
    accepted ? head(:no_content) : head(:unprocessable_entity)
  end

  private

    def set_player_character
      @player_character = PlayerCharacter.find(params.expect(:player_character_id))
    end

    def set_gambit
      @gambit = @player_character.gambits.find(params.expect(:id))
    end

    # Every write of the character's positions (create, move, destroy, reorder) runs in one transaction
    # holding a row lock on the character, so two concurrent requests can't both read the same positions
    # and write duplicates or gaps. The block reads the gambits after the lock (lock! reloads the character).
    def with_character_locked
      PlayerCharacter.transaction do
        @player_character.lock!
        yield
      end
    end

    # Positions 1..n in the given order, every row written (the unique position constraint is deferred to
    # the commit). Call it inside with_character_locked. Returns true.
    def rewrite_positions(gambits)
      gambits.each.with_index(1) { |gambit, position| gambit.update_columns(position:, updated_at: Time.current) }
      true
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
      @action_options = @player_character.gambit_action_options
    end
end
