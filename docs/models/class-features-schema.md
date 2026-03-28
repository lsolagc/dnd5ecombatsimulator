# Esquema de Banco: Habilidades de Classe (D&D 5e)

## Objetivo

Modelar habilidades para **todas as classes básicas do D&D 5e** (Bárbaro, Bardo, Bruxo, Clérigo, Druida, Feiticeiro, Guerreiro, Ladino, Mago, Monge, Paladino, Patrulheiro), mantendo **feitiços em tabela separada**.

## Tabelas

### `class_features`

Define a habilidade em si (identidade e comportamento base).

Campos:

- `player_class_id` (FK, obrigatório): classe dona da habilidade.
- `name` (string, obrigatório): nome da habilidade (ex.: `Second Wind`, `Rage`, `Ki`, `Channel Divinity`).
- `slug` (string, obrigatório, único por classe): chave estável para uso em código e seeds.
- `description` (text, obrigatório): descrição funcional da habilidade.
- `feature_type` (enum, obrigatório): `core`, `optional`, `subclass`, `subclass_progression`.
- `action_type` (enum, obrigatório): `passive`, `action`, `bonus_action`, `reaction`, `no_action`, `special`.
- `resource_name` (string, opcional): nome do recurso associado (ex.: `Ki`, `Rage`, `Channel Divinity`).
- `recharge_type` (enum, obrigatório): `none`, `short_rest`, `long_rest`, `short_or_long_rest`, `turn`, `round`, `special`.
- `grants_spellcasting` (boolean, obrigatório): marca habilidades como `Spellcasting` ou equivalentes, sem armazenar magias aqui.
- `source_book` (string, obrigatório): origem da regra (padrão: `PHB 2014`).
- `source_reference` (string, opcional): referência curta (ex.: `Fighter 2`).
- `notes` (text, opcional): observações de implementação/regras da mesa.

Índices:

- `index_class_features_on_player_class_id_and_slug` (único).

### `class_feature_unlocks`

Controla em quais níveis a habilidade aparece ou escala.

Campos:

- `class_feature_id` (FK, obrigatório): habilidade associada.
- `level` (integer, obrigatório, 1..20): nível de desbloqueio/escala.
- `action_type` (enum, opcional): override do custo de ação no nível.
- `recharge_type` (enum, opcional): override da recarga no nível.
- `uses` (integer, opcional): usos fixos no nível (ex.: Action Surge 1 no nível 2, 2 no nível 17).
- `uses_formula` (string, opcional): fórmula de uso variável (ex.: `proficiency_bonus`, `wisdom_modifier`, `spell_slots_table`).
- `resource_name` (string, opcional): override do nome do recurso no nível.
- `description` (text, opcional): descrição específica do marco de nível.
- `notes` (text, opcional): observações específicas.

Índices:

- `index_class_feature_unlocks_on_class_feature_id_and_level` (único).

## Por que isso cobre todas as classes básicas

- Habilidades passivas e ativas: cobertas por `action_type`.
- Recursos por descanso: cobertos por `resource_name`, `uses`, `uses_formula` e `recharge_type`.
- Escalonamento por nível: coberto por `class_feature_unlocks`.
- Habilidades que concedem conjuração, sem misturar com magias: cobertas por `grants_spellcasting`.
- Marcos de subclasse: cobertos por `feature_type`.

## Exemplos rápidos

- **Guerreiro / Action Surge**
  - `class_features`: `action_type = no_action`, `resource_name = Action Surge`, `recharge_type = short_or_long_rest`
  - `class_feature_unlocks`: nível 2 (`uses = 1`), nível 17 (`uses = 2`)

- **Monge / Ki**
  - `class_features`: `resource_name = Ki`, `recharge_type = short_rest`
  - `class_feature_unlocks`: nível 2 (`uses_formula = monk_level`)

- **Clérigo / Channel Divinity**
  - `class_feature_unlocks`: níveis de aumento de usos com `uses` por nível

- **Mago / Spellcasting**
  - `class_features`: `grants_spellcasting = true`
  - Magias e slots continuam fora desta modelagem (tabelas próprias de magia).