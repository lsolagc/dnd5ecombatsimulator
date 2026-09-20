# attacks_per_action was added with default 1 and db/seeds.rb never rewrites existing progression rows
# (ClassLevelProgression is frozen after_find), so Fighter rows seeded earlier stayed at 1 for every level.
# Raw SQL on purpose: the model's frozen records can't be updated.
class BackfillFighterAttacksPerAction < ActiveRecord::Migration[8.0]
  EXTRA_ATTACK_LEVELS = { 5..10 => 2, 11..19 => 3, 20..20 => 4 }.freeze

  def up
    each_fighter_range { |fighter_id, levels, attacks| set_attacks(fighter_id, levels, attacks) }
  end

  def down
    each_fighter_range { |fighter_id, levels, _| set_attacks(fighter_id, levels, 1) }
  end

  private

    def each_fighter_range
      fighter_id = select_value("SELECT id FROM player_classes WHERE name = 'Guerreiro'")
      return unless fighter_id

      EXTRA_ATTACK_LEVELS.each { |levels, attacks| yield fighter_id, levels, attacks }
    end

    def set_attacks(fighter_id, levels, attacks)
      execute <<~SQL
        UPDATE class_level_progressions SET attacks_per_action = #{attacks}
        WHERE player_class_id = #{fighter_id} AND level BETWEEN #{levels.min} AND #{levels.max}
      SQL
    end
end
