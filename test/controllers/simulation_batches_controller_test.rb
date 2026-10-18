require "test_helper"

class SimulationBatchesControllerTest < ActionDispatch::IntegrationTest
  test "new offers every character to both sides" do
    get new_simulation_batch_url

    assert_response :success
    assert_select "h2", text: "Lado A"
    assert_select "h2", text: "Lado B"
    assert_select "select[data-side=party_one] option[value='#{player_characters(:aragorn).id}']"
    assert_select "template[data-character-id='#{player_characters(:aragorn).id}'] input[name='simulation_batch[combatants][#{player_characters(:aragorn).id}][armor_class]'][value='16']"
  end

  test "new summarizes each combatant's enabled gambits, or random action without any" do
    aragorn, merlin = player_characters(:aragorn), player_characters(:merlin)
    Gambit.create!(owner: aragorn, position: 1, target: :enemy, condition: :lowest_hp, action_kind: :attack)
    Gambit.create!(owner: aragorn, position: 2, target: :enemy, condition: :any, action_kind: :attack, enabled: false)

    get new_simulation_batch_url

    assert_select "template[data-character-id='#{aragorn.id}'] .sim-card__gambits" do
      assert_select ".sim-card__gambits-rules", text: "1. Inimigo: menor HP → Ataque"
      assert_select "a[href='#{player_character_gambits_path(aragorn)}']", text: "Editar gambits"
    end
    assert_select "template[data-character-id='#{merlin.id}'] .sim-card__gambits-rules", text: "Ação aleatória"
  end

  test "show lists each combatant's gambits from the batch's copy" do
    aragorn, merlin = player_characters(:aragorn), player_characters(:merlin)
    Gambit.create!(owner: aragorn, position: 1, target: :enemy, condition: :lowest_hp, action_kind: :attack)
    Gambit.create!(owner: aragorn, position: 2, target: :enemy, condition: :any, action_kind: :attack, enabled: false)
    batch = SimulationBatch.create!(requested_count: 1, combatants: { aragorn.id => combatant_params("party_one"), merlin.id => combatant_params("party_two") })
    aragorn.gambits.destroy_all

    get simulation_batch_url(batch)

    assert_select ".sim-side--party_one details.sim-roster__gambits[open]" do
      assert_select "summary", text: "Gambits · 1 de 2 ligadas"
      assert_select "li", text: "1Inimigo: menor HP → Ataque"
      assert_select "li.is-off", text: "2Inimigo: qualquer → Ataque (desligado)"
    end
    assert_select ".sim-side--party_two .sim-roster__gambits", text: "Gambits · Aleatório"
  end

  test "create starts the experiment with the edited parameters" do
    aragorn, elora, merlin = player_characters(:aragorn), player_characters(:elora), player_characters(:merlin)

    assert_enqueued_jobs 20, only: SimulationRunJob do
      post simulation_batches_url, params: { simulation_batch: { requested_count: 20, combatants: {
        aragorn.id => combatant_params("party_one", armor_class: 19),
        elora.id => combatant_params("party_one"),
        merlin.id => combatant_params("party_two", defenses: { fire: "R" })
      } } }
    end

    batch = SimulationBatch.last
    assert_redirected_to simulation_batch_url(batch)
    assert_equal [ aragorn.id, elora.id ].sort, batch.party_one_ids.sort
    assert_equal 19, batch.combatant_settings[aragorn.id.to_s]["armor_class"]
    assert_equal({ "fire" => "R" }, batch.combatant_settings[merlin.id.to_s]["defenses"])
  end

  test "create refuses a combat with only one side and keeps the chosen cards" do
    aragorn = player_characters(:aragorn)

    assert_no_enqueued_jobs do
      post simulation_batches_url, params: { simulation_batch: { requested_count: 5, combatants: { aragorn.id => combatant_params("party_one", armor_class: 19) } } }
    end

    assert_response :unprocessable_entity
    assert_select "#error_explanation", text: /Cada lado do combate precisa de pelo menos um personagem/
    assert_select ".sim-side--party_one .sim-card input[name$='[armor_class]'][value='19']"
  end

  test "new from a finished experiment pre-fills its combatants and parameters" do
    aragorn, merlin = player_characters(:aragorn), player_characters(:merlin)
    batch = SimulationBatch.create!(requested_count: 40, combatants: {
      aragorn.id => combatant_params("party_one", armor_class: 21), merlin.id => combatant_params("party_two")
    })

    get new_simulation_batch_url(from: batch.id)

    assert_select ".sim-side--party_one .sim-card[data-character-id='#{aragorn.id}'] input[name$='[armor_class]'][value='21']"
    assert_select ".sim-side--party_one .sim-card .sim-field.is-edited[data-field=armor_class]"
    assert_select ".sim-side--party_two .sim-card[data-character-id='#{merlin.id}']"
    assert_select "input[name='simulation_batch[requested_count]'][value='40']"
  end

  test "cancel stops a running batch" do
    batch = SimulationBatch.create!(party_one_ids: [ player_characters(:aragorn).id ], party_two_ids: [ player_characters(:merlin).id ], requested_count: 5, status: "running")

    post cancel_simulation_batch_url(batch)

    assert batch.reload.cancelled?
    assert_redirected_to simulation_batch_url(batch)
  end

  test "logs downloads one JSON file with the header and every simulation, each with its seed" do
    batch = SimulationBatch.create!(party_one_ids: [ player_characters(:aragorn).id ], party_two_ids: [ player_characters(:merlin).id ], requested_count: 2)
    2.times { SimulationRunJob.perform_now(batch) }

    get logs_simulation_batch_url(batch)

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_includes response.headers["Content-Disposition"], %(filename="simulacoes-batch-#{batch.id}.json")
    log = JSON.parse(response.body)
    assert_equal %w[ header simulations ], log.keys
    assert_equal batch.simulation_runs.map(&:seed), log["simulations"].pluck("seed")
    assert log["simulations"].first.key?("round_log")
  end

  test "show summarizes a finished batch" do
    batch = SimulationBatch.create!(party_one_ids: [ player_characters(:aragorn).id ], party_two_ids: [ player_characters(:merlin).id ], requested_count: 3, status: "completed")
    [ [ "party_one", 10, 4, 7 ], [ "party_one", 5, 0, 12 ], [ nil, 0, 0, 3 ] ].each do |winner, done, wasted, damage|
      batch.simulation_runs.create!(seed: 1, elapsed_ms: 10, outcome: winner ? "victory" : "draw", winning_party: winner, result: {},
                                    healing_done: done, healing_wasted: wasted, max_round_damage: damage)
    end

    get simulation_batch_url(batch)

    assert_select "#batch_summary .sim-headline", text: /Lado A venceu 66,7% dos combates/
    { "Vitórias do lado A" => "66,7%", "Vitórias do lado B" => "0,0%", "Sem vencedor" => "33,3%" }.each do |label, value|
      assert_select "#batch_summary .sim-legend__item", text: /#{label}\s+#{Regexp.escape(value)}\s/
    end
    { "Cura realizada" => "15", "Cura desperdiçada" => "4", "Maior dano em um round" => "12" }.each do |label, value|
      assert_select ".sim-tile", text: /#{label}\s+#{value}\s/
    end
  end

  private

    def combatant_params(side, **overrides)
      { side:, current_hit_points: 8, armor_class: 16, attack_bonus: 4, damage_dice: "1d8", damage_type: "slashing", defenses: {} }.merge(overrides)
    end
end
