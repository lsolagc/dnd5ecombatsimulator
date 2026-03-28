# Habilidades do Guerreiro (D&D 5e)

## Escopo

Este documento lista as habilidades de classe do **Guerreiro** na **5ª edição (5e clássica/PHB 2014)**, do nível 1 ao 20.

- Não inclui habilidades específicas de subclasse (apenas os marcos em que elas são recebidas).
- Não inclui magias (Guerreiro base não possui lista de magias própria; isso depende de subclasse como Eldritch Knight).

## Tabela por Nível

| Nível | Habilidade | Custo de ação | Recurso e recarga | Descrição |
|---|---|---|---|---|
| 1 | Fighting Style | Passivo | Escolha permanente (pode mudar só com regra opcional) | Escolhe um estilo de combate que concede benefício passivo (ex.: Archery, Defense, Dueling, Great Weapon Fighting, Protection, Two-Weapon Fighting). |
| 1 | Second Wind | Ação bônus | 1 uso por descanso curto ou longo | Recupera pontos de vida iguais a 1d10 + nível de Guerreiro. |
| 2 | Action Surge (1 uso) | Sem ação separada; ativa no próprio turno para ganhar ação extra | 1 uso por descanso curto ou longo | No seu turno, ganha 1 ação adicional além da ação normal e possível ação bônus. |
| 3 | Martial Archetype | Passivo | Escolha de subclasse | Escolhe a subclasse marcial. Recebe habilidades de subclasse nos níveis 3, 7, 10, 15 e 18. |
| 4 | Ability Score Improvement | Passivo | Sem recarga | Aumenta atributos (+2 em um ou +1 em dois), respeitando limite de 20, ou troca por talento se a mesa usar feats. |
| 5 | Extra Attack | Passivo | Sem recarga | Ao usar a ação Atacar, faz 2 ataques em vez de 1. |
| 6 | Ability Score Improvement | Passivo | Sem recarga | Novo aumento de atributo (ou talento, se permitido). |
| 7 | Martial Archetype Feature | Varia por subclasse | Varia por subclasse | Recebe nova habilidade da subclasse escolhida. |
| 8 | Ability Score Improvement | Passivo | Sem recarga | Novo aumento de atributo (ou talento, se permitido). |
| 9 | Indomitable (1 uso) | Sem ação | 1 uso por descanso longo | Quando falha em um teste de resistência, pode rolar novamente e deve usar o novo resultado. |
| 10 | Martial Archetype Feature | Varia por subclasse | Varia por subclasse | Recebe nova habilidade da subclasse escolhida. |
| 11 | Extra Attack (2) | Passivo | Sem recarga | Ao usar a ação Atacar, passa a fazer 3 ataques. |
| 12 | Ability Score Improvement | Passivo | Sem recarga | Novo aumento de atributo (ou talento, se permitido). |
| 13 | Indomitable (2 usos) | Sem ação | 2 usos por descanso longo | Mesmo efeito de Indomitable, com mais usos antes do descanso longo. |
| 14 | Ability Score Improvement | Passivo | Sem recarga | Novo aumento de atributo (ou talento, se permitido). |
| 15 | Martial Archetype Feature | Varia por subclasse | Varia por subclasse | Recebe nova habilidade da subclasse escolhida. |
| 16 | Ability Score Improvement | Passivo | Sem recarga | Novo aumento de atributo (ou talento, se permitido). |
| 17 | Action Surge (2 usos) | Sem ação separada; ativa no próprio turno para ganhar ação extra | 2 usos por descanso curto ou longo (máx. 1 por turno) | Aumenta a quantidade de usos de Action Surge entre descansos. |
| 17 | Indomitable (3 usos) | Sem ação | 3 usos por descanso longo | Aumenta a quantidade de usos de Indomitable entre descansos longos. |
| 18 | Martial Archetype Feature | Varia por subclasse | Varia por subclasse | Recebe nova habilidade da subclasse escolhida. |
| 19 | Ability Score Improvement | Passivo | Sem recarga | Último aumento de atributo da classe (ou talento, se permitido). |
| 20 | Extra Attack (3) | Passivo | Sem recarga | Ao usar a ação Atacar, faz 4 ataques. |

## Resumo das Habilidades Base do Guerreiro

### Fighting Style (nível 1)
Escolha de especialização de combate com benefício passivo constante. Não gasta ação para funcionar.

### Second Wind (nível 1)
Cura própria de emergência. Usa ação bônus e recarrega em descanso curto ou longo.

### Action Surge (níveis 2 e 17)
Pico de ação no turno. Concede ação extra; começa com 1 uso por descanso curto/longo e sobe para 2 usos no nível 17.

### Martial Archetype (níveis 3, 7, 10, 15, 18)
Pacote de habilidades da subclasse do Guerreiro, recebido em marcos fixos.

### Ability Score Improvement (níveis 4, 6, 8, 12, 14, 16, 19)
Progressão de atributos acima da média da maioria das classes.

### Extra Attack (níveis 5, 11, 20)
Escalonamento principal ofensivo do Guerreiro: 2, depois 3, depois 4 ataques com a ação Atacar.

### Indomitable (níveis 9, 13, 17)
Ferramenta defensiva para repetir testes de resistência falhos, com mais usos em níveis altos.

## Observações de Implementação (Sistema)

- Em termos de modelagem, estas habilidades podem ficar em tabela separada de magias, como você definiu.
- Campos úteis para essa tabela de habilidades: `name`, `level_required`, `action_cost`, `resource_name`, `resource_uses`, `recharge_type`, `description`.
- Habilidades de subclasse podem usar o mesmo modelo com vínculo opcional para subclasse.

## Referência

Baseado na progressão do Guerreiro da 5e clássica (PHB 2014/SRD 5.1).