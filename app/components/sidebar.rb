class Components::Sidebar < Components::Base
  def view_template
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
        Link(href: player_classes_path, variant: :ghost) { "Player classes" }
      end
    end
  end
end
