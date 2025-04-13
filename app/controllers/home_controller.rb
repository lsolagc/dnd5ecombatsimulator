class HomeController < ApplicationController
  def index
    render Views::Home::Index.new
  end

  def ping
    render Views::Home::Ping.new, layout: false
  end
end
