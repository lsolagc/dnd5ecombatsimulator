# Componentes UI (Phlex)

## O que é Phlex?

Phlex é uma biblioteca Ruby que permite construir views como componentes reutilizáveis, combinando:
- Lógica (Ruby)
- Markup (HTML)
- Responsividade

Componentes Phlex vivem em `app/components/` e herdam de `Components::Base`.

## Estrutura Base

### Components::Base

```ruby
# app/components/base.rb
module Components
  class Base < Phlex::HTML
    include Rails.application.routes.url_helpers
    include ApplicationHelper
    
    # Integra helpers Rails:
    # - routes, links, forms
    # - truncate, sanitize, etc
  end
end
```

**Herdança:**
```
Phlex::HTML
  └─ Components::Base
      ├─ Components::Layout
      ├─ Components::Sidebar
      ├─ Components::PlayerClassComponents
      └─ RubyUI:: *
```

## Componentes Principais

### 1. Components::Layout

Layout base com cabeçalho e sidebar.

```ruby
# app/components/layout.rb
def template
  div(class: "flex h-screen") do
    render Sidebar.new
    main(class: "flex-1") { yield }
  end
end
```

**Uso:**
```
GET /player_characters
  → layouts/player_characters/index
    → Components::Layout
      → Sidebar + Content
```

### 2. Components::Sidebar

Navegação lateral.

```ruby
# Links para:
- Home
- Player Characters
- Player Classes
- Nova Personagem
```

### 3. Components::PlayerClassComponents

Formulários e views para Player Classes.

**Subcomponentes:**
- `PlayerClassForm` - Formulário de criação/edição
- `PlayerClassShow` - Exibição de classe

### 4. RubyUI

Biblioteca customizada com componentes comuns:

| Componente | Uso |
|-----------|-----|
| `Button` | Botões com estilos |
| `Form` | Wrappers de form |
| `Link` | Links estilizados |
| `Table` | Tabelas com paginação |
| `Typography` | Headings, paragraphs |
| `Card` | Cards com conteúdo |
| `Badge` | Badges/tags |

**Localizar:** `app/components/ruby_ui/`

## Criar um Novo Componente

### Template

```ruby
# app/components/my_component.rb
module Components
  class MyComponent < Base
    attr_reader :title, :content
    
    def initialize(title:, content:)
      @title = title
      @content = content
    end
    
    def template
      div(class: "my-component") do
        h2(class: "text-lg") { @title }
        p { @content }
      end
    end
  end
end
```

### Usar em View

```erb
<!-- app/views/pages/show.html.erb -->
<%= render Components::MyComponent.new(
  title: "Hello",
  content: "World"
) %>
```

### Ou em outro Phlex Component

```ruby
def template
  render MyComponent.new(title: "Hello", content: "World")
end
```

## Exemplo: Tabela de Personagens

```ruby
# app/components/player_characters_table.rb
module Components
  class PlayerCharactersTable < Base
    attr_reader :characters
    
    def initialize(characters)
      @characters = characters
    end
    
    def template
      render RubyUI::Table.new(
        headers: ["Nome", "Classe", "Nível", "HP", "Ações"],
        rows: characters.map { |c| row_for(c) }
      )
    end
    
    private
    
    def row_for(character)
      [
        character.name,
        character.player_class.name,
        character.current_level,
        "#{character.current_hp}/#{character.max_hp}",
        link_to("Ver", player_character_path(character))
      ]
    end
  end
end
```

**Uso:**
```ruby
# controller
@characters = PlayerCharacter.all

# view
<%= render Components::PlayerCharactersTable.new(@characters) %>
```

## Tailwind CSS Integration

Componentes usam Tailwind CSS para estilo:

```ruby
div(class: "flex justify-between items-center p-4") do
  h1(class: "text-2xl font-bold") { @title }
  button(class: "bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded") {
    "Enviar"
  }
end
```

**Classes úteis:**
- Layout: `flex`, `grid`, `absolute`, `relative`
- Spacing: `p-4`, `m-2`, `gap-3`
- Cores: `bg-blue-500`, `text-gray-700`, `border-red-200`
- Tamanho: `w-full`, `h-screen`, `text-lg`

## Forma sem Componente (ERB Tradicional)

Alguns projetos ainda usam ERB. No `dnd`:

```erb
<!-- app/views/player_characters/show.html.erb -->
<div class="container">
  <h1><%= @character.name %></h1>
  <p>Classe: <%= @character.player_class.name %></p>
  <p>Nível: <%= @character.current_level %></p>
  <p>HP: <%= @character.current_hp %>/<%= @character.max_hp %></p>
</div>
```

Renderizado como:
```ruby
render "player_characters/show"
```

## Organização de Componentes

```
app/components/
├── base.rb                    # Classe base
├── layout.rb                  # Layout principal
├── sidebar.rb                 # Navegação
├── player_class_components/
│   ├── form.rb               # Form de classe
│   └── show.rb               # Show de classe
├── ruby_ui/
│   ├── button.rb
│   ├── form.rb
│   ├── table.rb
│   └── typography.rb
└── [outros componentes]
```

## Debugging Componentes

### Console

```ruby
# app/components/my_component.rb
def template
  puts "Component rendering: title=#{@title}"
  div { @title }
end
```

### Test

```ruby
# test/components/my_component_test.rb
def test_renders_title
  component = Components::MyComponent.new(title: "Test")
  html = component.render_to_string
  assert_includes html, "Test"
end
```

---

Consulte a [documentação oficial Phlex](https://www.phlex.fun) para mais detalhes.
