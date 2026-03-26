# Setup do Projeto

## Pré-requisitos

- **Ruby**: 3.x
- **Rails**: 8.x
- **Node.js**: 18+
- **Yarn** ou **npm**
- **SQLite3** ou **PostgreSQL**
- **Git**

## Instalação

### 1. Clonar Repositório

```bash
git clone <repo-url>
cd dnd
```

### 2. Instalar Dependências Ruby

```bash
bundle install
```

### 3. Instalar Dependências JS

```bash
yarn install
# ou
npm install
```

### 4. Setup do Banco de Dados

```bash
# Criar banco, executar migrations
rails db:create
rails db:migrate

# (Opcional) Seed com dados iniciais
rails db:seed
```

### 5. Carregar Assets

```bash
./bin/dev
# Ou em outro terminal
./bin/importmap pin
```

## Rodando Localmente

### Modo Desenvolvimento

```bash
./bin/dev
```

Isso inicia:
- Rails server na porta 3000
- Tailwind CSS em watch mode
- JS bundler em watch mode

Acesse: http://localhost:3000

### Alternativa (sem ./bin/dev)

```bash
# Terminal 1: Rails
rails server

# Terminal 2: Tailwind
./bin/tailwindcss --watch

# Terminal 3: JS (se necessário)
./bin/importmap pin
```

## Testes

```bash
# Rodar todos os testes
rails test

# Rodar testes de models
rails test:models

# Rodar com coverage
rails test COVERAGE=true
```

## Linting

```bash
# RuboCop
./bin/rubocop

# Brakeman (segurança)
./bin/brakeman
```

## Estrutura de Pastas

```
dnd/
├── app/
│   ├── components/       # Phlex view components
│   ├── controllers/      # Rails controllers
│   ├── models/          # ActiveRecord models
│   ├── services/        # Serviços de lógica
│   ├── validators/      # Validadores customizados
│   ├── views/           # Views (maioria em Phlex)
│   └── javascript/      # JS ES6 modules
├── config/              # Configurações Rails
├── db/
│   ├── migrate/         # Migrations
│   ├── schema.rb        # Schema
│   └── seeds.rb         # Seed data
├── docs/                # Documentação (você está aqui)
├── lib/                 # Código compartilhado
│   └── dice/            # Sistema de dados/rolls
├── public/              # Arquivos estáticos
├── test/                # Testes
│
├── Gemfile              # Dependências Ruby
├── package.json         # Dependências JS
├── Procfile.dev         # Processos para ./bin/dev
└── README.md            # README principal
```

## Variáveis de Ambiente

Crie um arquivo `.env.local` ou use `.env`:

```bash
# Database (opcional, defaults para SQLite)
DATABASE_URL=postgresql://user:pass@localhost/dnd

# Rails master key (para credentials)
RAILS_MASTER_KEY=xxxxx
```

## Troubleshooting

### Erro: "Gem not found"

```bash
bundle install --local
# ou
bundle install
```

### Erro: "Database doesn't exist"

```bash
rails db:create db:migrate
```

### Assets não carregando

```bash
./bin/importmap pin
rails assets:precompile
```

### Porta 3000 em uso

```bash
rails server -p 3001
```

### JS não atualizando

```bash
# Limpar cache
rm -rf tmp/
./bin/dev  # reiniciar
```

## Docker (opcional)

```bash
# Build
docker build -t dnd .

# Run
docker run -p 3000:3000 dnd
```

## Próximos Passos

1. Leia [Visão Geral da Arquitetura](../architecture/overview.md)
2. Consulte [Criando Personagens](creating-characters.md)
3. Explore [Modelos de Dados](../models/data-model.md)

---

**Problemas?** Verifique que todas as dependências estão instaladas:
- `ruby -v` ≥ 3.0
- `rails -v` ≥ 8.0
- `node -v` ≥ 18
- `yarn -v` ou `npm -v`
