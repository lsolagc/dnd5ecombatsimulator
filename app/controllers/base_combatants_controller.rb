class BaseCombatantsController < ApplicationController
  before_action :set_base_combatant, only: %i[ show edit update destroy ]

  # GET /base_combatants or /base_combatants.json
  def index
    @base_combatants = BaseCombatant.all
  end

  # GET /base_combatants/1 or /base_combatants/1.json
  def show
  end

  # GET /base_combatants/new
  def new
    @base_combatant = BaseCombatant.new
  end

  # GET /base_combatants/1/edit
  def edit
  end

  # POST /base_combatants or /base_combatants.json
  def create
    @base_combatant = BaseCombatant.new(base_combatant_params)

    respond_to do |format|
      if @base_combatant.save
        format.html { redirect_to base_combatant_url(@base_combatant), notice: "Base combatant was successfully created." }
        format.json { render :show, status: :created, location: @base_combatant }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @base_combatant.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /base_combatants/1 or /base_combatants/1.json
  def update
    respond_to do |format|
      if @base_combatant.update(base_combatant_params)
        format.html { redirect_to base_combatant_url(@base_combatant), notice: "Base combatant was successfully updated." }
        format.json { render :show, status: :ok, location: @base_combatant }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @base_combatant.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /base_combatants/1 or /base_combatants/1.json
  def destroy
    @base_combatant.destroy

    respond_to do |format|
      format.html { redirect_to base_combatants_url, notice: "Base combatant was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_base_combatant
      @base_combatant = BaseCombatant.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def base_combatant_params
      params.require(:base_combatant).permit(:name, :armor_class, :hit_die, :hit_dice_number, :hitpoints, :proficiency_bonus, :strength, :dexterity, :constitution, :intelligence, :wisdom, :charisma, :skills)
    end
end
