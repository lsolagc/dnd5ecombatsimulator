# app/views/home/ping.rb
class Views::Home::Ping < Views::Base
  def page_title = "Home#Ping - RPG Combat Simulator"
  def view_template
    turbo_frame_tag "ping" do
      p { "🏓 Pong! #{Time.now.strftime('%H:%M:%S')}" }
    end
  end
end
