# Documentação - D&D Character Manager

Bem-vindo à documentação do **D&D Character Manager**, um sistema de gerenciamento de personagens e combates para Dungeons & Dragons construído em Rails com Phlex.

## 📚 Índice

### Arquitetura
- [Visão Geral](architecture/overview.md) - Estrutura geral da aplicação
- [Sistema de Classes](architecture/class-system.md) - Como funciona a progressão de classes e o multiataque do Guerreiro
- [Sistema de Combate](architecture/combat-system.md) - Motor de combate e encontros
- [Habilidades do Guerreiro (5e)](architecture/fighter-abilities-5e.md) - Lista completa de habilidades de classe até o nível 20

### Modelos
- [Modelos de Dados](models/data-model.md) - Descrição dos modelos principais e progressão de ataques por nível
- [Esquema de Habilidades de Classe](models/class-features-schema.md) - Modelagem de habilidades para todas as classes básicas (feitiços separados)

### Guias
- [Setup do Projeto](guides/setup.md) - Como instalar e rodar localmente
- [Criando Personagens](guides/creating-characters.md) - Fluxo de criação

### Componentes
- [Componentes UI](components/overview.md) - Phlex components e RubyUI

## 🎯 Começar Rápido

1. **Setup**: Veja [Setup do Projeto](guides/setup.md)
2. **Entender a Arquitetura**: Comece com [Visão Geral](architecture/overview.md)
3. **Explorar Modelos**: Consulte [Modelos de Dados](models/data-model.md)

## 🧭 Convenções do Projeto

### Migrations (Regra Global)

Para qualquer mudança de banco no projeto inteiro:

1. Gere a migration com gerador do Rails (`bin/rails generate migration ...`).
2. Edite o arquivo gerado para adicionar/ajustar tabelas, colunas, índices e chaves.
3. Não crie migrations manualmente escrevendo nome/timestamp do arquivo à mão.

## 🛠️ Para Agentes IA

Se você é um agente de IA (Copilot, Claude, etc):
- Consulte [.instructions.md](../.instructions.md) na raiz do projeto
- Este arquivo contém instruções específicas para navegação e desenvolvimento

## 📞 Estrutura de Diretórios

```
/docs
├── architecture/          # Decisões e sistemas principais
├── models/               # Documentação de modelos
├── guides/               # Tutoriais e howtos
├── components/           # Documentação de componentes UI
└── README.md            # Este arquivo
```

---

**Última atualização**: Março 2026
