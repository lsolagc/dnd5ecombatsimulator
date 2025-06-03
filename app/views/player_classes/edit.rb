# frozen_string_literal: true

class Views::PlayerClasses::Edit < Views::PlayerClasses::Base
  def page_title = "Editing player class"

  def initialize(player_class:, notice: nil)
    @player_class = player_class
    @notice = notice
  end

  def view_template
    div(class: "w-full") do
      if @notice.present?
        p(id: "notice", class: "py-2 px-3 bg-green-50 mb-5 text-green-500 font-medium rounded-md inline-block") { @notice }
      end

      div(class: "flex justify-between items-center") do
        Heading(level: 1, class: "font-bold text-4xl") { "Editing player class" }
        Link(href: player_classes_path, variant: :secondary) { "Back to player classes" }
      end

      render PlayerClassComponents::Form(player_class: @player_class)
    end
  end
end
