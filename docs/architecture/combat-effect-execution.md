# Execução de Efeitos em Combate

## Status

Implementado em Março/2026 (Fase 1).

Escopo entregue:

- Pipeline de execução de efeitos com `CombatAction`, `EffectResolver`, `EffectExecutor` e `ActionRunner`.
- Camada de rolagem expressiva com `RollExpression`, `RollContext` e `RollOutcome`.
- Campo `effect_payload` em `class_feature_unlocks` para definir efeito executável.
- Integração real de `Second Wind` como caso de uso inicial.
- Cobertura de testes para expressão, execução de efeito e fluxo completo.

Fora do escopo desta entrega:

- Migração do ataque básico do `EncounterService` para `CombatAction`.
- Feitiços e condições de controle no mesmo pipeline.
- Gestão transacional completa de recursos/recargas por descanso.

## Contexto

Hoje o combate está centrado em `EncounterService`, com fluxo de ataque básico:

1. `EncounterService` escolhe alvo e executa ataques.
2. `PlayerCharacter#roll_an_attack` cria `Dice::AttackRoll`.
3. `PlayerCharacter#get_attacked` e `#take_damage` aplicam resultado no alvo.

Esse fluxo funciona para ataque padrão, mas ainda não oferece um contrato reutilizável para:

- Habilidades de classe com regras próprias (ex.: `Second Wind` = cura `1d10 + nível de guerreiro`).
- Feitiços de dano/controle (tabela separada de habilidades, mas com execução no mesmo combate).
- Registro detalhado de rolagens e modificadores para log, auditoria e UI.

## Objetivo

Criar uma camada de execução de efeitos de combate que:

- Exponha rolagens e cálculos de forma padronizada.
- Permita reaproveitar o mesmo pipeline para habilidades e feitiços.
- Minimize acoplamento novo no `EncounterService`.

## Limitações observadas na codebase atual

1. `EncounterService` chama diretamente `roll_an_attack` e `get_attacked`.
2. `Dice::RollResult` retorna `natural` e `total`, mas não carrega metadados ricos de expressão/modificadores.
3. Não existe contrato explícito para ações não ofensivas (cura, buff, condição, etc).
4. Não existe camada única para custo/recurso/recarga (Action Surge, Ki, Spell Slot, etc).

## Proposta de Arquitetura

### 1. Introduzir `CombatAction` como entrada única

Representa o que o ator quer fazer no turno.

Campos sugeridos:

- `source_type` (`class_feature`, `spell`, `weapon_attack`, etc)
- `source_id` (id da habilidade/feitiço)
- `actor`
- `targets`
- `context` (nível de conjuração, modo da habilidade, etc)

### 2. Introduzir `EffectResolver`

Responsável por transformar `CombatAction` em efeitos executáveis.

Contrato sugerido:

```ruby
resolved = Combat::EffectResolver.call(action: combat_action)
# => [EffectInstance, EffectInstance, ...]
```

Cada `EffectInstance` representa uma operação atômica:

- `heal`
- `damage`
- `apply_condition`
- `grant_temp_hp`
- `resource_change`

### 3. Introduzir `EffectExecutor`

Aplica `EffectInstance` no estado do combate e retorna um resultado estruturado.

Contrato sugerido:

```ruby
result = Combat::EffectExecutor.call(
  effect: effect_instance,
  actor:,
  target:,
  combat_state:
)
```

`result` deve incluir:

- resultado mecânico (`applied`, `amount`, `saved`, `critical`)
- estado antes/depois (`hp_before`, `hp_after`)
- detalhes de rolagem (`rolls`)
- mensagens para log

### 4. Expor rolagens via `RollExpression`

Para suportar `1d10 + nível_de_guerreiro`, `2d6 + mod`, etc, sugerir uma camada específica:

- `RollExpression` (ex.: string parametrizada)
- `RollContext` (ator, alvo, nível, proficiência, modificadores)
- `RollOutcome` (dados rolados, breakdown, total)

Exemplo de payload:

```ruby
{
  expression: "1d10 + fighter_level",
  resolved_expression: "1d10 + 7",
  dice: [10],
  rolls: [6],
  modifiers: { fighter_level: 7 },
  total: 13
}
```

Isso resolve o requisito de "expor" a rolagem para o serviço de combate e para futuros sistemas (feitiços, itens, reações).

## Como mapear para as tabelas atuais

As tabelas `class_features` e `class_feature_unlocks` já modelam desbloqueio e recursos. Falta modelar o efeito executável.

Opção recomendada (incremental):

1. Adicionar em `class_feature_unlocks` um campo de definição de efeito (`effect_payload` em JSONB).
2. `EffectResolver` lê esse payload e gera `EffectInstance`.
3. Feitiços ganham estrutura equivalente em tabela própria de spells, mas com mesmo formato de `effect_payload`.

Estrutura mínima de `effect_payload`:

```json
{
  "kind": "heal",
  "roll": "1d10 + fighter_level",
  "target": "self",
  "damage_type": null,
  "save": null
}
```

Exemplo para `Second Wind`:

```json
{
  "kind": "heal",
  "roll": "1d10 + fighter_level",
  "target": "self"
}
```

## Estratégia de Integração sem quebrar o combate atual

Como `EncounterService` está documentado como congelado até refatoração maior, a integração deve ser progressiva.

### Fase 1 (baixa invasão)

1. Criar `Combat::ActionRunner` (resolver + executor).
2. Adicionar um único ponto de chamada no turno para ações especiais.
3. Manter ataque padrão atual como fallback.

Pseudo-fluxo:

```ruby
if combatant.has_selected_action?
  action_result = Combat::ActionRunner.call(...)
else
  # fluxo existente de ataque básico
end
```

### Fase 2 (padronização)

1. Migrar ataque básico para também virar `CombatAction`.
2. Unificar log de combate em formato de `EffectResult`.

### Fase 3 (expansão)

1. Integrar feitiços de dano/controle no mesmo pipeline.
2. Integrar recursos por descanso e gasto de usos no mesmo fluxo transacional.

## Recomendação técnica principal

Criar um contrato único de execução de efeito com três objetos centrais:

1. `CombatAction` (intenção)
2. `EffectResolver` (tradução de dados para efeito)
3. `EffectExecutor` (aplicação no estado)

Com isso, `Second Wind`, `Action Surge`, feitiços e futuras mecânicas passam a compartilhar infraestrutura, sem duplicar regras no serviço de combate.

## Checklist de implementação

1. Definir schema do `effect_payload` (JSON Schema simples em doc).
2. Implementar `RollExpression` com contexto (`fighter_level`, `ability_mod`, etc).
3. Implementar `EffectExecutor` para `heal` e `damage` primeiro.
4. Integrar `Second Wind` como primeiro caso real.
5. Adicionar testes de integração com log de rolagem completo.
6. Só depois expandir para feitiços.

## Implementação Atual (Fase 1)

### Componentes adicionados

- `app/services/combat/combat_action.rb`
- `app/services/combat/effect_instance.rb`
- `app/services/combat/effect_resolver.rb`
- `app/services/combat/effect_executor.rb`
- `app/services/combat/action_runner.rb`
- `app/services/combat/roll_expression.rb`
- `app/services/combat/roll_context.rb`
- `app/services/combat/roll_outcome.rb`

### Persistência

Migration adicionada:

- `db/migrate/20260330000001_add_effect_payload_to_class_feature_unlocks.rb`

Novo campo:

- `class_feature_unlocks.effect_payload :jsonb`

Exemplo real (fixture de `Second Wind`):

```yaml
effect_payload:
  kind: heal
  roll: "1d10 + actor_level"
  target: self
```

### Contratos práticos

#### 1) Intent

```ruby
action = Combat::CombatAction.new(
  source_type: :class_feature,
  source_id: feature.id,
  actor: fighter,
  targets: []
)
```

#### 2) Runner

```ruby
results = Combat::ActionRunner.call(action: action)
# => [Combat::EffectExecutor::Result]
```

#### 3) Atalho no modelo

`PlayerCharacter` recebeu `use_class_feature(slug:, targets: [])`, que monta o `CombatAction` e delega ao `ActionRunner`.

### Shape do resultado

`Combat::EffectExecutor::Result` retorna:

- `kind` (`:heal` ou `:damage`)
- `applied`
- `amount`
- `hp_before`
- `hp_after`
- `roll_outcome` (com expressão original, expressão resolvida, dados/modificadores e total)
- `message`

### Testes adicionados

- `test/services/combat/roll_expression_test.rb`
- `test/services/combat/effect_executor_test.rb`
- `test/services/combat/action_runner_test.rb`

Cobertura validada com execução da suíte completa (`bin/rails test`) sem regressões.