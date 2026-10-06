module SimulationBatchesHelper
  SIDES = { "party_one" => "A", "party_two" => "B" }.freeze
  DEFENSE_LABELS = { "R" => "Resistência", "I" => "Imunidade", "V" => "Vulnerabilidade" }.freeze

  def simulation_sides
    SIDES
  end

  def defense_labels
    DEFENSE_LABELS
  end

  def format_milliseconds(milliseconds)
    return "—" if milliseconds.nil?

    seconds = milliseconds / 1000.0
    if seconds < 1 then "#{milliseconds.round} ms"
    elsif seconds < 60 then "#{number_with_precision(seconds, precision: 1, separator: ",")} s"
    else "#{(seconds / 60).floor} min #{(seconds % 60).round} s"
    end
  end

  def share(count, total)
    total.zero? ? 0.0 : 100.0 * count.to_i / total
  end

  def format_share(value)
    number_to_percentage(value, precision: 1, separator: ",")
  end

  # "HP 12 · CA 16 · +5 · 1d8 cortante"
  def combat_line(settings, max_hit_points)
    bonus = settings["attack_bonus"].to_i
    [
      "HP #{settings["current_hit_points"]}/#{max_hit_points}",
      "CA #{settings["armor_class"]}",
      bonus.negative? ? bonus.to_s : "+#{bonus}",
      "#{settings["damage_dice"]} #{damage_type_labels[settings["damage_type"]].to_s.downcase}"
    ].join(" · ")
  end
end
