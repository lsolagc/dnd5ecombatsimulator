class PlayerCharactersController < ApplicationController
  before_action :set_player_character, only: %i[ show edit update destroy ]

  # GET /player_characters or /player_characters.json
  def index
    @player_characters = PlayerCharacter.all
  end

  # GET /player_characters/1 or /player_characters/1.json
  def show
  end

  # GET /player_characters/new
  def new
    @player_character = PlayerCharacter.new
  end

  # GET /player_characters/1/edit
  def edit
  end

  # POST /player_characters or /player_characters.json
  def create
    @player_character = PlayerCharacter.new(player_character_params)

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
      @player_character = PlayerCharacter.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def player_character_params
      params.expect(player_character: [ :name, :level, :player_class_id ])
    end
end
