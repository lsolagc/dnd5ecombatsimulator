require "test_helper"

class GambitsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @character = player_characters(:thorin)
    @attack, @second_wind, @surge = [
      { position: 1, target: :enemy, action_kind: :attack },
      { position: 2, target: :self, action_kind: :class_feature, class_feature: class_features(:fighter_second_wind) },
      { position: 3, target: :self, action_kind: :class_feature, class_feature: class_features(:fighter_action_surge) }
    ].map { |attributes| Gambit.create!(owner: @character, condition: :any, **attributes) }
  end

  test "index shows the rules and the new gambit form" do
    get player_character_gambits_url(@character)

    assert_response :success
    assert_select "h1", "Gambits de Thorin"
    assert_select "[data-gambits-target=slot]", 3
    assert_select "#new_gambit form"
  end

  test "create adds the rule at the next position, decoding the action select" do
    post player_character_gambits_url(@character),
      params: { gambit: { target: "self", condition: "hp_below", condition_value: "40", action: "class_feature:#{class_features(:fighter_second_wind).id}" } }

    assert_redirected_to player_character_gambits_url(@character)
    created = @character.gambits.reload.last
    assert_equal [ 4, "hp_below", 40, class_features(:fighter_second_wind).id ], [ created.position, created.condition, created.condition_value, created.class_feature_id ]
  end

  test "a 7th gambit is refused with the error on the screen" do
    3.times { |index| Gambit.create!(owner: @character, position: 4 + index, target: :enemy, condition: :any, action_kind: :attack) }

    assert_no_difference("Gambit.count") do
      post player_character_gambits_url(@character), params: { gambit: { target: "enemy", condition: "any", action: "attack" } }
    end
    assert_response :unprocessable_entity
    assert_select "#new_gambit_errors", /No máximo 6 gambits/
    assert_select "#new_gambit", 0
  end

  test "update edits target, condition, value and action; an invalid combination re-renders with the error in the slot" do
    patch player_character_gambit_url(@character, @attack),
      params: { gambit: { target: "self", condition: "hp_below", condition_value: "30", action: "class_feature:#{class_features(:fighter_second_wind).id}" } }
    assert_redirected_to player_character_gambits_url(@character)
    assert_equal [ "self", "hp_below", 30, "class_feature" ], @attack.reload.values_at(:target, :condition, :condition_value, :action_kind)

    patch player_character_gambit_url(@character, @attack), params: { gambit: { target: "self", condition: "any", condition_value: "", action: "attack" } }
    assert_response :unprocessable_entity
    assert_select "##{ActionView::RecordIdentifier.dom_id(@attack)} .alert-danger", /O alvo não combina com a ação/
    assert_equal "class_feature", @attack.reload.action_kind
  end

  test "a tampered target, condition or action is a validation error, never a 500" do
    [ { target: "boss" }, { condition: "hp_maybe" }, { action: "potion:1" } ].each do |tampered|
      patch player_character_gambit_url(@character, @attack),
        params: { gambit: { target: "enemy", condition: "any", condition_value: "", action: "attack" }.merge(tampered) }

      assert_response :unprocessable_entity, tampered.inspect
      assert_equal [ "enemy", "any", "attack" ], @attack.reload.values_at(:target, :condition, :action_kind)
    end
  end

  test "switching to a condition without a value saves and clears the stored value" do
    @surge.update!(condition: :resource_at_least, condition_value: 1)
    @attack.update!(condition: :hp_below, condition_value: 40)

    # As the screen sends it: the hidden value field is disabled, so no condition_value at all.
    patch player_character_gambit_url(@character, @attack), params: { gambit: { target: "enemy", condition: "any", action: "attack" } }
    assert_redirected_to player_character_gambits_url(@character)
    assert_equal [ "any", nil ], @attack.reload.values_at(:condition, :condition_value)

    # Without JS the stale value is still submitted: also cleared.
    patch player_character_gambit_url(@character, @surge),
      params: { gambit: { target: "self", condition: "any", condition_value: "1", action: "class_feature:#{class_features(:fighter_action_surge).id}" } }
    assert_redirected_to player_character_gambits_url(@character)
    assert_equal [ "any", nil ], @surge.reload.values_at(:condition, :condition_value)
  end

  test "toggle flips enabled" do
    patch toggle_player_character_gambit_url(@character, @attack)
    assert_not @attack.reload.enabled?
    patch toggle_player_character_gambit_url(@character, @attack)
    assert @attack.reload.enabled?
  end

  test "move swaps the middle rule with its neighbor only, up and down, and at either end moves nothing" do
    lowest = Gambit.create!(owner: @character, position: 4, target: :enemy, condition: :lowest_hp, action_kind: :attack)
    order = -> { @character.gambits.reload.map { |gambit| [ gambit.id, gambit.position ] } }
    expected = ->(*gambits) { gambits.each.with_index(1).map { |gambit, position| [ gambit.id, position ] } }

    patch move_player_character_gambit_url(@character, @surge, direction: "up")
    assert_redirected_to player_character_gambits_url(@character)
    assert_equal expected.(@attack, @surge, @second_wind, lowest), order.(), "3rd of 4 up: swaps with the 2nd only"

    patch move_player_character_gambit_url(@character, @surge, direction: "down")
    assert_equal expected.(@attack, @second_wind, @surge, lowest), order.(), "back down: swaps with its neighbor only"

    patch move_player_character_gambit_url(@character, @second_wind, direction: "down")
    assert_equal expected.(@attack, @surge, @second_wind, lowest), order.(), "2nd of 4 down: swaps with the 3rd only"

    patch move_player_character_gambit_url(@character, @attack, direction: "up")
    assert_redirected_to player_character_gambits_url(@character)
    patch move_player_character_gambit_url(@character, lowest, direction: "down")
    assert_redirected_to player_character_gambits_url(@character)
    assert_equal expected.(@attack, @surge, @second_wind, lowest), order.(), "the ends do not move"
  end

  test "move with a direction other than up or down is a 422 and moves nothing" do
    before = @character.gambits.reload.map { |gambit| [ gambit.id, gambit.position ] }

    [ "sideways", "", nil ].each do |direction|
      patch move_player_character_gambit_url(@character, @second_wind, direction:)
      assert_response :unprocessable_entity, direction.inspect
    end
    assert_equal before, @character.gambits.reload.map { |gambit| [ gambit.id, gambit.position ] }
  end

  test "destroy removes the rule and compacts positions to 1..n" do
    delete player_character_gambit_url(@character, @attack)

    assert_redirected_to player_character_gambits_url(@character)
    assert_equal [ [ @second_wind.id, 1 ], [ @surge.id, 2 ] ], @character.gambits.reload.map { |gambit| [ gambit.id, gambit.position ] }
  end

  test "reorder rewrites every position from ids[]" do
    patch reorder_player_character_gambits_url(@character), params: { ids: [ @surge.id, @attack.id, @second_wind.id ] }

    assert_response :no_content
    assert_equal [ [ @surge.id, 1 ], [ @attack.id, 2 ], [ @second_wind.id, 3 ] ], @character.gambits.reload.map { |gambit| [ gambit.id, gambit.position ] }
  end

  test "reorder refuses anything but an exact permutation of the character's gambits, changing nothing" do
    foreign = Gambit.create!(owner: player_characters(:aragorn), position: 1, target: :enemy, condition: :any, action_kind: :attack)
    before = @character.gambits.reload.map { |gambit| [ gambit.id, gambit.position ] }

    [
      [ @surge.id, @attack.id ],                              # missing one
      [ @surge.id, @attack.id, @attack.id ],                  # duplicate
      [ @surge.id, @attack.id, @second_wind.id, @attack.id ], # all of them plus a duplicate
      [ @surge.id, @attack.id, foreign.id ],                  # another character's gambit
      [ @surge.id, @attack.id, @second_wind.id, foreign.id ], # extra
      []
    ].each do |ids|
      patch reorder_player_character_gambits_url(@character), params: { ids: }
      assert_response :unprocessable_entity, "accepted #{ids.inspect}"
    end

    assert_equal before, @character.gambits.reload.map { |gambit| [ gambit.id, gambit.position ] }
    assert_equal 1, foreign.reload.position
  end

  test "reorder answers 422, never a 500, to ids that are not a list of ids" do
    before = @character.gambits.reload.map { |gambit| [ gambit.id, gambit.position ] }

    garbage = @character.gambits.map { |gambit| "#{gambit.id}abc" } # a permutation once to_i drops the garbage
    [ { a: "1" }, @attack.id.to_s, [ { a: @attack.id } ], nil, garbage ].each do |ids|
      patch reorder_player_character_gambits_url(@character), params: { ids: }
      assert_response :unprocessable_entity, "ids: #{ids.inspect}"
    end
    assert_equal before, @character.gambits.reload.map { |gambit| [ gambit.id, gambit.position ] }
  end

  test "another character's gambit is a 404 on every member action" do
    foreign = Gambit.create!(owner: player_characters(:aragorn), position: 1, target: :enemy, condition: :any, action_kind: :attack)

    patch player_character_gambit_url(@character, foreign), params: { gambit: { target: "enemy", condition: "lowest_hp", action: "attack" } }
    assert_response :not_found
    patch toggle_player_character_gambit_url(@character, foreign)
    assert_response :not_found
    patch move_player_character_gambit_url(@character, foreign, direction: "down")
    assert_response :not_found
    delete player_character_gambit_url(@character, foreign)
    assert_response :not_found

    assert_equal [ "any", true ], foreign.reload.values_at(:condition, :enabled)
  end

  test "save_preset creates a preset holding a copy of the character's rules" do
    assert_difference("GambitPreset.count", 1) do
      post save_preset_player_character_gambits_url(@character), params: { name: "  Guerreiro  " }
    end

    assert_redirected_to player_character_gambits_url(@character)
    assert_equal "Preset Guerreiro salvo.", flash[:notice]
    preset = GambitPreset.find_by!(name: "Guerreiro")
    assert_equal rule_rows(@character), rule_rows(preset)
    assert_empty preset.gambits.ids & @character.gambits.ids
  end

  test "save_preset with a duplicate (any case) or blank name is a 422 with the error on the screen, creating nothing" do
    GambitPreset.create!(name: "Guerreiro")

    { "gUERREIRO" => "Já existe um preset com esse nome", "  " => "Dê um nome ao preset", nil => "Dê um nome ao preset" }.each do |name, error|
      assert_no_difference([ "GambitPreset.count", "Gambit.count" ]) do
        post save_preset_player_character_gambits_url(@character), params: { name: }.compact
      end
      assert_response :unprocessable_entity
      assert_select "#preset_errors", error
    end
  end

  test "save_preset from a character without rules is refused, creating nothing" do
    character = player_characters(:aragorn)

    assert_no_difference([ "GambitPreset.count", "Gambit.count" ]) do
      post save_preset_player_character_gambits_url(character), params: { name: "Vazio" }
    end
    assert_response :unprocessable_entity
    assert_select "#preset_errors", /sem regras para salvar/
  end

  test "save_preset losing a race for the name (unique index) is a 422, never a 500" do
    # Another tab saves the same name between this request's validation and its INSERT.
    GambitPreset.class_eval { before_create { GambitPreset.insert_all([ { name: "CORRIDA", created_at: Time.current, updated_at: Time.current } ]) } }

    post save_preset_player_character_gambits_url(@character), params: { name: "corrida" }

    assert_response :unprocessable_entity
    assert_select "#preset_errors", "Já existe um preset com esse nome"
    assert_equal 0, GambitPreset.count # the stand-in row rolls back with this request (in production it is another tab's, committed)
  ensure
    GambitPreset.reset_callbacks(:create)
  end

  test "save_preset with a name that is not a string is refused" do
    assert_no_difference("GambitPreset.count") do
      post save_preset_player_character_gambits_url(@character), params: { name: [ "x" ] }
    end
    assert_response :unprocessable_entity
  end

  test "overwrite_preset from a character without rules is refused, leaving the preset as it was" do
    preset = GambitPreset.create!(name: "Cheio")
    Gambit.create!(owner: preset, position: 1, target: :enemy, condition: :marked, action_kind: :attack)

    patch overwrite_preset_player_character_gambits_url(player_characters(:aragorn)), params: { preset_id: preset.id }

    assert_response :unprocessable_entity
    assert_select "#preset_errors", /sem regras para salvar/
    assert_equal [ "marked" ], preset.gambits.reload.map(&:condition)
  end

  test "applying an empty preset is refused, leaving the character's rules" do
    preset = GambitPreset.create!(name: "Vazio")

    patch apply_preset_player_character_gambits_url(@character), params: { preset_id: preset.id }

    assert_response :unprocessable_entity
    assert_select "#preset_errors", /não tem regras/
    assert_equal 3, @character.gambits.reload.size
  end

  test "overwrite_preset replaces the preset's rules with a copy of the character's" do
    preset = GambitPreset.create!(name: "Velho")
    Gambit.create!(owner: preset, position: 1, target: :enemy, condition: :marked, action_kind: :attack)

    patch overwrite_preset_player_character_gambits_url(@character), params: { preset_id: preset.id }

    assert_redirected_to player_character_gambits_url(@character)
    assert_equal "Preset Velho sobrescrito.", flash[:notice]
    assert_equal rule_rows(@character), rule_rows(preset)
  end

  test "apply_preset replaces only this character's rules with a copy of the preset's" do
    preset = GambitPreset.create!(name: "Arqueiro")
    Gambit.create!(owner: preset, position: 1, target: :enemy, condition: :lowest_hp, action_kind: :attack)
    other = Gambit.create!(owner: player_characters(:aragorn), position: 1, target: :enemy, condition: :any, action_kind: :attack)

    patch apply_preset_player_character_gambits_url(@character), params: { preset_id: preset.id }

    assert_redirected_to player_character_gambits_url(@character)
    assert_equal "Preset Arqueiro aplicado.", flash[:notice]
    assert_equal rule_rows(preset), rule_rows(@character)
    assert_equal [ other.id ], player_characters(:aragorn).gambits.reload.ids, "another character is untouched"
    assert_equal 1, preset.gambits.count
  end

  test "apply_preset with a rule that does not hold at the character's level refuses the whole preset, naming the rule" do
    second_wind = class_features(:fighter_second_wind)
    second_wind.class_feature_unlocks.create!(level: 10, description: "Test: becomes an attack.",
                                              effect_payload: { kind: "damage", roll: "1d6", target: "enemy" })
    preset = GambitPreset.create!(name: "Alto nível")
    Gambit.create!(owner: preset, position: 1, target: :enemy, condition: :lowest_hp, action_kind: :attack)
    Gambit.create!(owner: preset, position: 2, target: :enemy, condition: :any, action_kind: :class_feature, class_feature: second_wind)
    before = rule_rows(@character)

    patch apply_preset_player_character_gambits_url(@character), params: { preset_id: preset.id }

    assert_response :unprocessable_entity
    assert_select "#preset_errors", /regra 2 \(Inimigo: qualquer → Second Wind\) não vale para Thorin no nível 5\. O alvo não combina/
    assert_equal before, rule_rows(@character), "nothing changes, not even the rules before the invalid one"
    assert_select "#preset_errors", count: 1
  end

  test "save_preset and overwrite_preset refuse a rule that holds at the character's level but not at the feature's highest" do
    class_features(:fighter_second_wind).class_feature_unlocks.create!(level: 10, description: "Test: becomes an attack.",
                                                                       effect_payload: { kind: "damage", roll: "1d6", target: "enemy" })
    preset = GambitPreset.create!(name: "Existente")
    Gambit.create!(owner: preset, position: 1, target: :enemy, condition: :lowest_hp, action_kind: :attack)
    before = rule_rows(preset)

    assert_no_difference -> { GambitPreset.count } do
      post save_preset_player_character_gambits_url(@character), params: { name: "Novo" }
    end
    assert_response :unprocessable_entity
    assert_select "#preset_errors", /regra 2 \(Self: qualquer → Second Wind\) não vale para o preset Novo\. O alvo não combina/

    patch overwrite_preset_player_character_gambits_url(@character), params: { preset_id: preset.id }
    assert_response :unprocessable_entity
    assert_select "#preset_errors", /regra 2 \(Self: qualquer → Second Wind\) não vale para o preset Existente/
    assert_equal before, rule_rows(preset)
  end

  test "apply_preset keeps a rule for a feature the character has not unlocked yet: an action it lacks, skipped at runtime" do
    level_one = player_characters(:aragorn)
    preset = GambitPreset.create!(name: "Mestre")
    Gambit.create!(owner: preset, position: 1, target: :enemy, condition: :any, action_kind: :class_feature,
                   class_feature: class_features(:fighter_battle_master_maneuver_precision_attack))

    patch apply_preset_player_character_gambits_url(level_one), params: { preset_id: preset.id }

    assert_redirected_to player_character_gambits_url(level_one)
    assert_equal [ class_features(:fighter_battle_master_maneuver_precision_attack).id ], level_one.gambits.reload.map(&:class_feature_id)
  end

  test "an unknown preset is a 404 on overwrite and apply, a malformed id a 400, changing nothing" do
    before = rule_rows(@character)

    patch overwrite_preset_player_character_gambits_url(@character), params: { preset_id: 0 }
    assert_response :not_found
    patch apply_preset_player_character_gambits_url(@character), params: { preset_id: 0 }
    assert_response :not_found
    patch apply_preset_player_character_gambits_url(@character), params: { preset_id: { id: 1 } }
    assert_response :bad_request
    assert_equal before, rule_rows(@character)
  end

  private

    def rule_rows(owner)
      Gambit.where(owner:).order(:position).map { |gambit| gambit.attributes.slice(*Gambit::SNAPSHOT_ATTRIBUTES) }
    end
end
