class HomeController < ApplicationController
  def index
    @player_characters_count = PlayerCharacter.count
    @player_classes_count = PlayerClass.count
  end

  def ping
    render layout: false
  end
end
