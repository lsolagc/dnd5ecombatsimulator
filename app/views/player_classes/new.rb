# frozen_string_literal: true

class Views::PlayerClasses::New < Views::PlayerClasses::Base
  def page_title = "New player class"

  def initialize(player_class: nil, notice: nil)
    @player_class = player_class || model_class.new
    @notice = notice
  end

  def view_template
    div(class: "w-full") do
      if @notice.present?
        p(id: "notice", class: "py-2 px-3 bg-green-50 mb-5 text-green-500 font-medium rounded-md inline-block") { @notice }
      end

      div(class: "flex justify-between items-center") do
        Heading(level: 1, class: "font-bold text-4xl") { "New player class" }
      end

      render PlayerClassComponents::Form(player_class: @player_class)
    end
  end
end
