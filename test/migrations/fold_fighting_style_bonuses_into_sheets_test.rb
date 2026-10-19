require "test_helper"
require Rails.root.join("db/migrate/20261019002857_fold_fighting_style_bonuses_into_sheets")

class FoldFightingStyleBonusesIntoSheetsTest < ActiveSupport::TestCase
  test "down takes the fighting style bonuses off the sheets into their unlocks, up folds them back" do
    unlock = ->(fixture) { class_feature_unlocks(fixture).reload }
    sheets = -> { %i[fighter_defender fighter_archer aragorn].map { |name| player_characters(name).combatant.reload.slice(:armor_class, :attack_bonus) } }
    folded = sheets.()

    migrate(:down)
    assert_equal [ folded[0].merge("armor_class" => 16), folded[1].merge("attack_bonus" => 0), folded[2] ], sheets.()
    assert_equal({ "kind" => "modifier", "trigger" => "always", "modifier" => "armor_class", "value" => 1 }, unlock.(:fighting_style_defense_level_1).effect_payload)
    assert_equal({ "kind" => "modifier", "trigger" => "always", "modifier" => "attack_bonus", "value" => 2 }, unlock.(:fighting_style_archery_level_1).effect_payload)
    assert_equal "Aplicado incondicionalmente porque o uso de armadura não é rastreado pelo motor.", unlock.(:fighting_style_defense_level_1).notes

    migrate(:up)
    assert_equal folded, sheets.()
    assert_nil unlock.(:fighting_style_defense_level_1).effect_payload
    assert_nil unlock.(:fighting_style_archery_level_1).notes
  end

  private

    def migrate(direction)
      ActiveRecord::Migration.suppress_messages { FoldFightingStyleBonusesIntoSheets.new.migrate(direction) }
    end
end
