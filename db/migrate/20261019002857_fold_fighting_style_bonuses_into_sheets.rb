# The sheet now holds the final AC and attack bonus (as read in combat), so Fighting Style: Defense (+1 AC)
# and Archery (+2 to hit) move from their unlock's passive modifier into the sheet of every character who
# chose them. A snapshot of the data: slugs, values and texts are fixed here, raw SQL so it doesn't depend on
# the models. Saved simulation batches are left alone (decided with the user: test data): their snapshot holds
# the base AC and attack bonus, so a batch saved before, or repeated, runs a Defense or Archery fighter 1 or 2 lower.
class FoldFightingStyleBonusesIntoSheets < ActiveRecord::Migration[8.0]
  STYLES = {
    "fighting-style-defense" => {
      column: "armor_class", value: 1,
      notes: "Aplicado incondicionalmente porque o uso de armadura não é rastreado pelo motor."
    },
    "fighting-style-archery" => {
      column: "attack_bonus", value: 2,
      notes: "Aplicado a todo ataque (não só à distância) porque o motor não distingue arma corpo-a-corpo de arma à distância."
    }
  }.freeze

  def up
    STYLES.each do |slug, style|
      shift_sheets(slug, style[:column], style[:value])
      set_unlock(slug, payload: nil, notes: nil)
    end
  end

  def down
    STYLES.each do |slug, style|
      shift_sheets(slug, style[:column], -style[:value])
      payload = { kind: "modifier", trigger: "always", modifier: style[:column], value: style[:value] }
      set_unlock(slug, payload: payload.to_json, notes: style[:notes])
    end
  end

  private

    def shift_sheets(slug, column, delta)
      execute <<~SQL
        UPDATE combatants SET #{column} = #{column} + (#{delta})
        FROM player_characters, class_features
        WHERE combatants.combatable_type = 'PlayerCharacter' AND combatants.combatable_id = player_characters.id
          AND class_features.id = player_characters.fighting_style_id AND class_features.slug = #{connection.quote(slug)}
      SQL
    end

    def set_unlock(slug, payload:, notes:)
      execute <<~SQL
        UPDATE class_feature_unlocks SET effect_payload = #{connection.quote(payload)}::jsonb, notes = #{connection.quote(notes)}
        WHERE level = 1 AND class_feature_id IN (SELECT id FROM class_features WHERE slug = #{connection.quote(slug)})
      SQL
    end
end
