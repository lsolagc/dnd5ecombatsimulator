class Components::Layout < Components::Base
  def initialize(page_info)
    @page_info = page_info
  end

  def view_template
    doctype

    html do
      head do
        title { @page_info.title }
        raw helpers.stylesheet_link_tag("tailwind", "data-turbo-track": "reload")
        raw helpers.javascript_importmap_tags
        raw helpers.turbo_include_tags
      end
    end

    body(class: "text-gray-200") do
      aside(class: "fixed bg-slate-800 h-screen top-0 left-0 z-40 w-64 transition-transform -translate-x-full sm:translate-x-0") do
        # fixed: posição fixa na tela, independente do scroll ou de outros elementos
        # bg-color-number: cor de fundo
        # h-screen: altura da tela inteira
        # top-0: posição no topo da tela
        # left-0: posição na esquerda da tela
        # z-40: camada de sobreposição (z-index)
        # w-64: largura de 16rem (256px)
        # transition-transform: transição suave para transformações
        # -translate-x-full: move o elemento para fora da tela à esquerda em qualquer tamanho de tela
        # sm:translate-x-0: remove a transformação em telas pequenas (sm) e maiores
        div(class: "p-4") do
          # p-4: padding de 1rem (16px)
          h1 { "<aside>" }
          p { "Find me in app/components/layout.rb" }
        end
      end
      div(class: "sm:ml-64 p-4 bg-slate-700 h-screen") do
        # sm:ml-64: margem à esquerda de 16rem (256px) em telas pequenas (sm) e maiores
        # px-4: padding horizontal de 1rem (16px)
        yield
      end
    end
  end
end
