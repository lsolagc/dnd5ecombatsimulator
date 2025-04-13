# frozen_string_literal: true

class Views::Home::Index < Views::Base
  def page_title = "Home#Index - RPG Combat Simulator"

  def view_template
    h1 { "Home::Index" }
    p(class: "text-blue-500") { "Se você está vendo isso, Tailwind está funcionando " }

    h1 { "Ping com Turbo Frame" }

    turbo_frame_tag "ping" do
      p { "Ainda não clicou." }
    end

    Link(
      href: "/ping",
      data: { turbo_frame: "ping" },
    ) { "Ping!" }
  end
end
