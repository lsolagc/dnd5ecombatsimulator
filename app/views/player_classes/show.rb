# frozen_string_literal: true

class Views::PlayerClasses::Show < Views::Base
  def initialize(player_class:, notice: nil)
    @player_class = player_class
    @notice = notice
  end

  def view_template
    div(class: "md:w-2/3 w-full") do
      if @notice.present?
        p(
          class:
            "py-2 px-3 bg-green-50 mb-5 text-green-500 font-medium rounded-md inline-block",
          id: "notice"
        ) { @notice }
      end
      Heading(level: 1, class: "font-bold text-4xl") { "Showing player class" }

      render PlayerClassComponents::Show.new(player_class: @player_class)

      Link(href: edit_player_class_path(@player_class), variant: :primary) { "Edit this player class" }
      Link(href: player_classes_path, variant: :secondary) { "Back to player classes" }

      # TODO: transform this into a component
      button_to "Destroy this player class",
                @player_class,
                method: :delete,
                # form_class: "sm:inline-block mt-2 sm:mt-0 sm:ml-2",
                class:
                  "whitespace-nowrap inline-flex items-center justify-center rounded-md font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 bg-destructive text-destructive-foreground shadow-sm hover:bg-destructive/90 px-4 py-2 h-9 text-sm text-stone-100 cursor-pointer",
                data: {
                  turbo_confirm: "Are you sure?"
                }
    end
  end
end
