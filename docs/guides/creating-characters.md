# Criando Personagens

## Fluxo básico

1. **Acessar formulário**: GET `/player_characters/new`
2. **Preencher dados**: Nome, classe, ability scores
3. **Submeter**: POST `/player_characters`
4. **Ver personagem**: GET `/player_characters/:id`

## Via Interface (UI)

### Passo 1: Navegar

Clique em "Nova Personagem" ou acesse:
```
http://localhost:3000/player_characters/new
```

### Passo 2: Preencher Formulário

| Campo | O que é | Range |
|-------|---------|-------|
| **Nome** | Nome do personagem | string |
| **Classe** | Seleção dropdown (Wizard, Fighter, etc) | dropdown |
| **Strength** | Força (STR) | 1-20 |
| **Dexterity** | Destreza (DEX) | 1-20 |
| **Constitution** | Constituição (CON) | 1-20 |
| **Intelligence** | Inteligência (INT) | 1-20 |
| **Wisdom** | Sabedoria (WIS) | 1-20 |
| **Charisma** | Carisma (CHA) | 1-20 |

### Passo 3: Submeter

Clique em "Criar Personagem"

O sistema:
1. Valida todos os campos
2. Calcula HP inicial: `hit_die + CON_modifier`
3. Define nível inicial: 1
4. Define bônus de proficiência inicial: +2
5. Redireciona para página do personagem

## Via API (Rails Console ou HTTP)

### Console Rails

```ruby
rails console

# Criar classe (se não existir)
fighter = PlayerClass.find_or_create_by(
  name: "Fighter",
  hit_die: :d10,
  spellcasting_modifier: :none
)

# Criar personagem
character = PlayerCharacter.create!(
  name: "Conan",
  player_class: fighter,
  strength: 18,
  dexterity: 14,
  constitution: 16,
  intelligence: 10,
  wisdom: 13,
  charisma: 12
)

character.id      # => 1
character.max_hp  # => 13 (10 + 3 CON mod)
character.current_hp  # => 13
```

### HTTP POST

```bash
curl -X POST http://localhost:3000/player_characters \
  -H "Content-Type: application/json" \
  -d '{
    "player_character": {
      "name": "Aragorn",
      "player_class_id": 1,
      "strength": 16,
      "dexterity": 17,
      "constitution": 15,
      "intelligence": 12,
      "wisdom": 14,
      "charisma": 15
    }
  }'
```

## Cálculo de HP Inicial

O HP inicial é calculado automaticamente:

```
HP = hit_die_value + CON_modifier

Exemplos:

1. Fighter (d10), CON 16 (mod +3)
   HP = 10 + 3 = 13

2. Wizard (d6), CON 14 (mod +2)
   HP = 6 + 2 = 8

3. Barbarian (d12), CON 18 (mod +4)
   HP = 12 + 4 = 16
```

## Ability Scores

**Valores válidos: 1-20**

| Score | Típico Para | Modificador |
|-------|-------------|-------------|
| 3-4 | Criança | -4 a -3 |
| 8-9 | Fraco | -1 |
| 10-11 | Médio | 0 |
| 12-13 | Bom | +1 |
| 14-15 | Muito Bom | +2 |
| 16-17 | Excepcional | +3 |
| 18-19 | Heróico | +4 |
| 20 | Divino | +5 |

## Classe e Progressão

Ao criar um personagem, ele vem com:
- **Level**: 1
- **Proficiency Bonus**: +2
- **Class**: Selecionada no formulário

### Modificador de Proficiência por Nível

| Nível | Bônus |
|-------|-------|
| 1-4 | +2 |
| 5-8 | +3 |
| 9-12 | +4 |
| 13-16 | +5 |
| 17-20 | +6 |

## Validação

O sistema valida:

✅ Nome não vazio  
✅ Classe selecionada  
✅ Todos os ability scores entre 1-20  
✅ Classe existe  

❌ Erro se algum campo inválido

## Exemplo Completo: Criar Mago

```
Nome: Gandalf
Classe: Wizard
STR: 10 (modifier: 0)
DEX: 14 (modifier: +2)
CON: 13 (modifier: +1)
INT: 18 (modifier: +4)
WIS: 16 (modifier: +3)
CHA: 12 (modifier: +1)

Resultado:
- HP = 6 (d6 wizard) + 1 (CON mod) = 7
- Level: 1
- Proficiency: +2
- Spellcasting Modifier: INT (+4)
```

## Ver Personagem Criado

Após criar, você é redirecionado para:

```
GET /player_characters/:id
```

Mostra:
- Estatísticas completas
- Status de combate (HP atual/máx)
- Nível e bônus de proficiência
- Botões para editar ou deletar

## Próximos Passos

- **Editar**: Botão "Editar" na página do personagem
- **Combate**: Veja [Sistema de Combate](../architecture/combat-system.md)

---

Pronto! Seu personagem está criado e pronto para combate.
