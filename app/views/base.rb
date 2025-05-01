# frozen_string_literal: true

class Views::Base < Components::Base
  include Components
  # The `Views::Base` is an abstract class for all your views.

  # nulify the layout for views rendered inside other views
  # there may be a way to not need this if, instead of rendering a view inside a view,
  # we render a component inside a view
  def layout = Layout

  PageInfo = Data.define(:title)
  # By default, it inherits from `Components::Base`, but you
  # can change that to `Phlex::HTML` if you want to keep views and
  # components independent.
  def around_template
    if layout
      render layout.new(page_info) do
        super
      end
    else
      super
    end
  end

  def page_info
    PageInfo.new(
      title: try(:page_title) || "RPG Combat Simulator",
    )
  end
end
