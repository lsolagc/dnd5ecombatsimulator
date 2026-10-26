class PlayerCharactersController < ApplicationController
  before_action :set_player_character, only: %i[ show edit update destroy ]
  before_action :set_player_classes, only: %i[ new create edit update ]

  # GET /player_characters or /player_characters.json
  def index
    @player_characters = PlayerCharacter.includes(:player_class, :combatant).order(:name)
  end

  # GET /player_characters/1 or /player_characters/1.json
  def show
  end

  # GET /player_characters/new
  def new
    @player_character = PlayerCharacter.new
    @player_character.build_combatant
  end

  # GET /player_characters/1/edit
  def edit
  end

  # POST /player_characters or /player_characters.json
  def create
    @player_character = PlayerCharacter.new(player_character_params)
    assign_damage_type_flags(@player_character)

    respond_to do |format|
      if @player_character.save
        format.html { redirect_to @player_character, notice: "Player character was successfully created." }
        format.json { render :show, status: :created, location: @player_character }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @player_character.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /player_characters/1 or /player_characters/1.json
  def update
    assign_damage_type_flags(@player_character)

    respond_to do |format|
      if @player_character.update(player_character_params)
        format.html { redirect_to @player_character, notice: "Player character was successfully updated." }
        format.json { render :show, status: :ok, location: @player_character }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @player_character.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /player_characters/1 or /player_characters/1.json
  def destroy
    @player_character.destroy!

    respond_to do |format|
      format.html { redirect_to player_characters_path, status: :see_other, notice: "Player character was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_player_character
      @player_character = PlayerCharacter
        .includes(:combatant, player_class: [ :class_level_progressions, { class_features: :class_feature_unlocks } ])
        .find(params.expect(:id))
    end

    def set_player_classes
      @player_classes = PlayerClass.includes(:class_level_progressions, class_features: :class_feature_unlocks).order(:name)
    end

    # Only allow a list of trusted parameters through.
    def player_character_params
      params.expect(
        player_character: [
          :name, :level, :player_class_id, :max_hit_points_input,
          combatant_attributes: [ :id, :armor_class, :speed, :strength, :dexterity, :constitution, :intelligence, :wisdom, :charisma, :attack_bonus, :damage_dice, :damage_type ]
        ]
      )
    end

    # Damage chips submit a single R/I/V/"" flag per damage type (player_character[damage_type_flags][fire]),
    # written through Combatant#defenses= (a type left out, or with an unknown flag, has no defense).
    def assign_damage_type_flags(player_character)
      flags = params.dig(:player_character, :damage_type_flags)
      return unless flags.respond_to?(:permit)

      combatant = player_character.combatant || player_character.build_combatant
      combatant.defenses = flags.permit(*Combatant::Defenses::TYPES).to_h
        .select { |_type, flag| Combatant::Defenses::FLAGS.key?(flag) }
    end
end
