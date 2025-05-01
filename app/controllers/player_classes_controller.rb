class PlayerClassesController < ApplicationController
  before_action :set_player_class, only: %i[ show edit update destroy ]

  # GET /player_classes or /player_classes.json
  def index
    @player_classes = PlayerClass.all
    render Views::PlayerClasses::Index.new(player_classes: @player_classes)
  end

  # GET /player_classes/1 or /player_classes/1.json
  def show
    render Views::PlayerClasses::Show.new(player_class: @player_class)
  end

  # GET /player_classes/new
  def new
    render Views::PlayerClasses::New
    # @player_class = PlayerClass.new # não necessário para o Phlex
  end

  # GET /player_classes/1/edit
  def edit
    render Views::PlayerClasses::Edit.new(player_class: @player_class)
    # render Views::PlayerClasses::Edit.new(player_classes: @player_classes)
  end

  # POST /player_classes or /player_classes.json
  def create
    @player_class = PlayerClass.new(player_class_params)

    respond_to do |format|
      if @player_class.save
        format.html { redirect_to @player_class, notice: "Player class was successfully created." }
        format.json { render :show, status: :created, location: @player_class }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @player_class.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /player_classes/1 or /player_classes/1.json
  def update
    respond_to do |format|
      if @player_class.update(player_class_params)
        format.html { redirect_to @player_class, notice: "Player class was successfully updated." }
        format.json { render :show, status: :ok, location: @player_class }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @player_class.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /player_classes/1 or /player_classes/1.json
  def destroy
    @player_class.destroy!

    respond_to do |format|
      format.html { redirect_to player_classes_path, status: :see_other, notice: "Player class was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_player_class
      @player_class = PlayerClass.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def player_class_params
      params.expect(player_class: [ :name, :hit_die, :description, :spellcasting_modifier ])
    end
end
