require "application_system_test_case"
require "net/http"

class SimulationBatchesTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  # Workers push progress over Action Cable. The test adapter never reaches the browser, so these tests
  # deliver broadcasts in-process to the app server Capybara runs.
  setup do
    @cable_config = ActionCable.server.config.cable
    ActionCable.server.config.cable = { "adapter" => "async" }
    ActionCable.server.config.disable_request_forgery_protection = true
    ActionCable.server.restart
  end

  teardown do
    ActionCable.server.config.cable = @cable_config
    ActionCable.server.config.disable_request_forgery_protection = false
    ActionCable.server.restart
  end

  test "builds an experiment with edited parameters, runs it and shows the result" do
    visit new_simulation_batch_url

    add :party_one, :aragorn
    add :party_one, :elora
    add :party_two, :aragorn_copy
    assert_text "2 contra 1 · 100 simulações"

    within card(:aragorn) do
      fill_in "CA", with: 19
      fill_in "HP inicial", with: 7
      find("summary", text: "Defesas").click
      click_on "fogo"
      assert_text "3 ajustes"
      assert_selector ".sim-field.is-edited[data-field=armor_class]"
    end
    fill_in "Simulações", with: 5
    page.save_screenshot(Rails.root.join("tmp/screenshots/simulation_batch_new.png"))

    click_on "Iniciar experimento"
    assert_text "0 / 5 simulações finalizadas"
    assert_text "HP 7/12 · CA 19 · +0 · 1d4 concussão"
    assert_selector ".sim-tag", text: "R fogo"
    assert_stream_connected
    assert_enqueued_jobs 5, only: SimulationRunJob
    perform_enqueued_jobs

    # The workers push the result to the open page: no reload, no polling.
    within("#batch_summary") do
      assert_text "Vitórias do lado A"
      assert_text "Vitórias do lado B"
      assert_text "Sem vencedor"
    end
    assert_text "Cura realizada"
    assert_text "Cura desperdiçada"
    assert_text "Maior dano em um round"

    batch = SimulationBatch.last
    assert batch.completed?
    assert_equal 5, batch.simulation_runs.count
    assert_equal 5, batch.simulation_runs.distinct.count(:seed), "every simulation gets its own seed"
    assert_equal({ "fire" => "R" }, batch.combatant_settings[player_characters(:aragorn).id.to_s]["defenses"])
    assert_equal 16, player_characters(:aragorn).reload.armor_class, "the character sheet is not changed"
    assert_link "Baixar logs (JSON, .zip)"
  end

  test "a seeded experiment runs exactly one simulation, summarizes it and downloads its log" do
    visit new_simulation_batch_url

    add :party_one, :aragorn
    add :party_one, :elora
    add :party_two, :merlin
    add :party_two, :aragorn_copy
    fill_in "Seed (opcional)", with: "42"
    assert_field "Simulações", with: "1", disabled: true
    assert_text "2 contra 2 · 1 simulação"
    page.save_screenshot(Rails.root.join("tmp/screenshots/simulation_batch_seed.png"))

    click_on "Iniciar experimento"
    assert_text "Seed 42: rolagens reproduzíveis"
    assert_stream_connected
    perform_enqueued_jobs

    run = SimulationBatch.last.simulation_runs.sole
    assert_equal 42, run.seed
    { "Vitórias do lado A" => run.winning_party == "party_one" ? "100,0%" : "0,0%",
      "Vitórias do lado B" => run.winning_party == "party_two" ? "100,0%" : "0,0%" }.each do |label, value|
      assert_selector "#batch_summary .sim-legend__item", text: /#{label}\s+#{Regexp.escape(value)}\s/
    end
    { "Cura realizada" => run.healing_done, "Cura desperdiçada" => run.healing_wasted, "Maior dano em um round" => run.max_round_damage }.each do |label, value|
      assert_selector ".sim-tile", text: /#{label}\s+#{value}\s/
    end
    page.save_screenshot(Rails.root.join("tmp/screenshots/simulation_batch_summary.png"))

    files = download_zip(find_link("Baixar logs (JSON, .zip)")[:href])
    assert_equal %w[ batch.json simulation-0001.json ], files.keys
    assert_equal 42, files["simulation-0001.json"]["seed"]
    assert_equal run.result["round_log"], files["simulation-0001.json"]["round_log"]
    assert_equal 42, files["batch.json"]["seed"]
    assert_equal 4, files["batch.json"]["combatant_settings"].size
  end

  test "repeating an experiment brings back its combatants and parameters to tweak" do
    aragorn = player_characters(:aragorn)
    batch = SimulationBatch.create!(requested_count: 30, status: "completed", combatants: {
      aragorn.id => { side: "party_one", current_hit_points: 9, armor_class: 21, attack_bonus: 0, damage_dice: "1d4", damage_type: "bludgeoning" },
      player_characters(:merlin).id => { side: "party_two", current_hit_points: 8, armor_class: 12, attack_bonus: 0, damage_dice: "1d4", damage_type: "bludgeoning" }
    })

    visit simulation_batch_url(batch)
    click_on "Repetir com ajustes"

    within card(:aragorn) do
      assert_field "CA", with: "21"
      assert_field "HP inicial", with: "9"
      click_on "Restaurar ficha"
      assert_field "CA", with: "16"
      assert_field "HP inicial", with: aragorn.max_hit_points.to_s
      assert_no_text "ajuste"
    end
    assert_field "Simulações", with: "30"
  end

  test "a character picked for one side cannot be picked again, and removing it frees it" do
    visit new_simulation_batch_url

    add :party_one, :aragorn
    aragorn_id = player_characters(:aragorn).id.to_s
    assert find("select[data-side=party_two] option[value='#{aragorn_id}']").disabled?

    within(card(:aragorn)) { find("button[aria-label='Remover Aragorn']").click }
    assert_no_selector card(:aragorn)
    assert_not find("select[data-side=party_two] option[value='#{aragorn_id}']").disabled?
  end

  test "clearing the seed unlocks the simulation count" do
    visit new_simulation_batch_url

    fill_in "Seed (opcional)", with: "42"
    assert_field "Simulações", with: "1", disabled: true
    assert_text "Travado em 1 com seed."

    # Backspace like a user would: Selenium's clear() fires no input event.
    find_field("Seed (opcional)").send_keys(:backspace, :backspace)
    assert_field "Simulações", with: "100", disabled: false
    assert_text "De 1 a 1000."
  end

  test "refuses a combat with only one side" do
    visit new_simulation_batch_url

    add :party_one, :aragorn
    add :party_one, :elora
    assert_text "Os dois lados precisam de pelo menos um combatente"
    click_on "Iniciar experimento"

    assert_text "Cada lado do combate precisa de pelo menos um personagem"
    assert_selector card(:aragorn) # the chosen combatants survive the error
    assert_equal 0, SimulationBatch.count
    page.save_screenshot(Rails.root.join("tmp/screenshots/simulation_batch_one_side.png"))
  end

  test "refuses more than 1000 simulations and a starting HP above the sheet's maximum" do
    visit new_simulation_batch_url

    add :party_one, :aragorn
    add :party_two, :merlin
    fill_in "Simulações", with: 1001
    click_on "Iniciar experimento"
    assert_current_path new_simulation_batch_path
    assert_not_empty find_field("Simulações").evaluate_script("this.validationMessage")

    fill_in "Simulações", with: 10
    within(card(:merlin)) { fill_in "HP inicial", with: 99 }
    click_on "Iniciar experimento"
    assert_current_path new_simulation_batch_path
    assert_not_empty within(card(:merlin)) { find_field("HP inicial").evaluate_script("this.validationMessage") }
    assert_equal 0, SimulationBatch.count
  end

  test "a running experiment updates its progress live and can be interrupted" do
    batch = SimulationBatch.create!(party_one_ids: [ player_characters(:aragorn).id ], party_two_ids: [ player_characters(:merlin).id ],
                                    requested_count: 10, status: "running")
    batch.simulation_runs.create!(seed: 1, elapsed_ms: 40, outcome: "victory", winning_party: "party_one", result: {})

    visit simulation_batch_url(batch)

    assert_text "1 / 10 simulações finalizadas"
    assert_selector ".sim-progress-stats", text: /Tempo médio\s+40 ms/i
    assert_selector ".progress-bar[style*='10.0%']"
    page.save_screenshot(Rails.root.join("tmp/screenshots/simulation_batch_running.png"))

    # Another simulation finishes in a worker, which pushes the progress: the page morphs in place, so the
    # bar is the same element (kept by reference below) and its width eases to the new value instead of jumping.
    assert_stream_connected
    page.execute_script("window.progressBarBefore = document.querySelector('.progress-bar')")
    batch.simulation_runs.create!(seed: 2, elapsed_ms: 60, outcome: "victory", winning_party: "party_two", result: {})
    batch.broadcast_progress(force: true)
    assert_text "2 / 10 simulações finalizadas"
    assert_selector ".sim-progress-stats", text: /Tempo médio\s+50 ms/i
    assert_selector ".progress-bar[style*='20.0%']"
    assert evaluate_script("window.progressBarBefore === document.querySelector('.progress-bar')"), "the bar must be morphed, not replaced"

    click_on "Interromper"

    assert_text "Experimento interrompido após 2 de 10 simulações"
    assert batch.reload.cancelled?
    assert_no_button "Interromper"
    assert_selector "#batch_summary .sim-headline", text: "Empate técnico: cada lado venceu 50,0% dos combates."
    page.save_screenshot(Rails.root.join("tmp/screenshots/simulation_batch_cancelled.png"))
  end

  private

    def assert_stream_connected
      assert_selector "turbo-cable-stream-source[connected]", visible: :all
    end

    def add(side, fixture)
      find("select[data-side=#{side}]").find("option[value='#{player_characters(fixture).id}']").select_option
    end

    def card(fixture)
      ".sim-card[data-character-id='#{player_characters(fixture).id}']"
    end

    # Fetches the link from the running app server and returns { entry name => parsed JSON }.
    def download_zip(href)
      response = Net::HTTP.get_response(URI.join(page.current_url, href))
      assert_equal "application/zip", response.content_type

      files = {}
      Zip::InputStream.open(StringIO.new(response.body)) do |zip|
        while (entry = zip.get_next_entry)
          files[entry.name] = JSON.parse(zip.read)
        end
      end
      files
    end
end
