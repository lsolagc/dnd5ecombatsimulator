# frozen_string_literal: true

class Components::Base < Phlex::HTML
  include Components
  include RubyUI

  # Include any helpers you want to be available across all components
  include Phlex::Rails::Helpers
  include Phlex::Rails::Helpers::Routes
  include Phlex::Rails::Helpers::TurboFrameTag
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::Pluralize

  register_output_helper :stylesheet_link_tag
  register_output_helper :javascript_importmap_tags
  register_output_helper :turbo_include_tags

  if Rails.env.development?
    def before_template
      comment { "Before #{self.class.name}" }
      super
    end
  end
end
