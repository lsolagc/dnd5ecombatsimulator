# frozen_string_literal: true

class Components::PlayerClassComponents::Show < Components::Base
  def initialize(player_class:, notice: nil)
    @player_class = player_class
    @notice = notice
  end

  def view_template
    div(id: (dom_id @player_class), class: "w-full sm:w-auto my-5 space-y-5") do
      div do
        strong(class: "block font-medium mb-1") { "Name:" }
        plain @player_class.name
      end
      div do
        strong(class: "block font-medium mb-1") { "Hit die:" }
        plain @player_class.hit_die
      end
      div do
        strong(class: "block font-medium mb-1") { "Description:" }
        plain @player_class.description
      end
      div do
        strong(class: "block font-medium mb-1") { "Spellcasting modifier:" }
        plain @player_class.spellcasting_modifier
      end
    end
  end
end
