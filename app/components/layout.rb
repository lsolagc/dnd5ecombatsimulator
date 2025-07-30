class Components::Layout < Components::Base
  def initialize(page_info)
    @page_info = page_info
  end

  def view_template
    doctype

    html do
      head do
        title { @page_info.title }
        stylesheet_link_tag("tailwind", "data-turbo-track": "reload")
        javascript_importmap_tags
        turbo_include_tags
      end

      body(class: "text-gray-200") do
        render Sidebar
        div(class: "sm:ml-64 p-4 bg-slate-700 h-screen") do
          # sm:ml-64: margem à esquerda de 16rem (256px) em telas pequenas (sm) e maiores
          # px-4: padding horizontal de 1rem (16px)
          yield
        end
      end
    end
  end
end
