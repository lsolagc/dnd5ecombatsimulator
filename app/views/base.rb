# frozen_string_literal: true

class Views::Base < Components::Base
  include Components
  # The `Views::Base` is an abstract class for all your views.
  def layout = Layout

  PageInfo = Data.define(:title)
  # By default, it inherits from `Components::Base`, but you
  # can change that to `Phlex::HTML` if you want to keep views and
  # components independent.
  def around_template
    render layout.new(page_info) do
      super
    end
  end

  def page_info
    PageInfo.new(
      title: page_title
    )
  end
end
