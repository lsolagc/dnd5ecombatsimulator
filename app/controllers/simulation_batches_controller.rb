class SimulationBatchesController < ApplicationController
  before_action :set_simulation_batch, only: %i[ show cancel logs ]

  def new
    source = SimulationBatch.find_by(id: params[:from]) if params[:from]
    @simulation_batch = source ? source.rerun : SimulationBatch.new(requested_count: 100)
  end

  def create
    @simulation_batch = SimulationBatch.new(simulation_batch_params)

    if @simulation_batch.save
      ActiveJob.perform_all_later(Array.new(@simulation_batch.requested_count) { SimulationRunJob.new(@simulation_batch) })
      redirect_to @simulation_batch
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def cancel
    @simulation_batch.cancel!
    @simulation_batch.broadcast_progress(force: true)
    redirect_to @simulation_batch
  end

  def logs
    send_data @simulation_batch.logs_json, filename: "simulacoes-batch-#{@simulation_batch.id}.json", type: "application/json"
  end

  private

    def set_simulation_batch
      @simulation_batch = SimulationBatch.find(params.expect(:id))
    end

    def simulation_batch_params
      params.expect(simulation_batch: [ :requested_count, :seed, combatants: {} ])
    end
end
