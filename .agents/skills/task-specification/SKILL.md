---
name: task-specification
description: 'Transforme pedido vago em demanda operável antes de qualquer triagem, planejamento ou implementação neste simulador de D&D. Use para esclarecer intenção, escopo, restrições e critérios de aceite antes de acionar build.'
argument-hint: 'Descreva a demanda inicial e o que já é conhecido (objetivo, limites, prazo, artefato esperado).'
user-invocable: true
---

# Especificação de Tarefa

Transforma pedidos vagos em demandas operáveis. Não implementa código, não altera nem executa
mudanças no projeto: a atuação termina na coleta de informações e na remoção de ambiguidades.

## Objetivo
- Entender a intenção real da demanda.
- Ler primeiro o mínimo de documentação relevante para evitar perguntas sobre pontos já documentados.
- Identificar lacunas de contexto que bloqueiam execução segura.
- Fazer somente as perguntas mínimas necessárias.
- Consolidar escopo, restrições e critérios de aceite verificáveis.
- Quando necessário, decompor uma demanda complexa em tarefas menores e mais operáveis.
- Explicitar dependências, pré-condições e bloqueios entre tarefas quando isso for necessário para remover ambiguidades.

## Não Fazer
- Não ler toda a documentação disponível por padrão.
- Não implementar código.
- Não editar, criar, mover ou remover arquivos do projeto.
- Não sugerir que a mudança já foi feita ou iniciar execução técnica.
- Não propor mudanças técnicas detalhadas de arquitetura.
- Não abrir análise extensa de arquivos sem necessidade (a verificação de premissas descrita abaixo é permitida, pontual e somente leitura).
- Não confundir especificação com triagem de fluxo.
- Não transformar a decomposição em plano técnico detalhado de implementação.

## Processo
1. Reescreva a demanda em uma frase objetiva (problema + resultado esperado).
2. Comece pelo README raiz como ponto de partida documental mínimo antes de perguntar ao usuário.
3. Expanda a leitura somente se a documentação inicial indicar outras fontes diretamente relevantes para a demanda.
4. Liste o que já está claro e o que está faltando, incluindo o resultado da Verificação de Premissas e das Perguntas de Refinamento (seções abaixo).
5. Pergunte apenas o mínimo para destravar a execução, evitando pedir ao usuário algo que já esteja documentado.
6. Se a demanda for complexa, decomponha em tarefas menores com limites claros de escopo.
7. Defina escopo dentro/fora, dependências principais, pré-condições e possíveis bloqueios.
8. Feche com critérios de aceite testáveis e próximos passos para outro agente ou para o usuário.

## Regra de Leitura Mínima de Documentação
- Antes de perguntar ao usuário, consulte um ponto de partida documental mínimo e relevante para a demanda.
- Comece obrigatoriamente pelo README raiz do repositório.
- A partir do README raiz, siga para documentação de arquitetura, guias ou modelos apenas se isso for necessário para a demanda.
- Não percorra toda a árvore de documentação por padrão.
- Só leia documentação adicional quando a primeira fonte consultada apontar explicitamente para outra referência necessária ou quando isso evitar uma pergunta que o projeto já respondeu.
- Se a documentação não resolver a lacuna crítica, então pergunte ao usuário.

## Verificação de Premissas contra o Código
Somente leitura e em divulgação progressiva (progressive disclosure): para cada premissa factual do pedido (funções, pontos de chamada, contagens, nomes, campos citados), só suba de nível quando o anterior não bastar.
1. `.okf/index.md`: o OKF do repo é o mapa de código e a fonte de verdade. Use-o para achar o documento que cobre o assunto (`.okf/architecture/`, `.okf/models/`).
2. O documento OKF específico.
3. Só então grep ou leitura pontual do trecho de código que o OKF aponta, para confirmar a premissa.

- Não varra o repositório, não execute nada que altere estado e não proponha arquitetura.
- Premissa que não bate com o OKF, divergência entre o OKF e o código, ou assunto sem cobertura no OKF vai para "Lacunas de Contexto", com o que foi encontrado e a indicação de que o OKF precisa ser atualizado.

## Perguntas de Refinamento
Responda cada uma com evidência (código ou documentação), não com opinião. Leve ao usuário as que mudam o comportamento observável da simulação ou contradizem um critério de aceite; o restante decida e registre na saída.
1. Que comportamento observável no simulador mostra que a tarefa serve ao objetivo maior, além de um teste unitário passar?
2. O texto da tarefa se contradiz ou contradiz o código (inclui/exclui, critérios, premissas de fato)?
3. Onde o motor obriga a simplificar o 5e, e qual o impacto estimado na métrica (baixo/médio/alto)?
4. A funcionalidade é alcançável com conteúdo real (seed/UI) ou só por fixture de teste?
5. Há bug ou simplificação conhecida que distorce a métrica? Se sim, deve virar tarefa, não nota repetida.
6. Quais invariantes transversais se aplicam (sequência de RNG, consumo único de recurso)? Cada uma vira critério de aceite com o teste que deve falhar quando ela for sabotada.

## Perguntas Mínimas (use apenas quando faltar contexto)
- Qual resultado final você espera ver no sistema?
- Quais arquivos/áreas podem ser alterados e quais não podem?
- Existe regra de negócio obrigatória (5e/projeto) que precisa ser preservada?
- Como validar que deu certo (teste, simulação, output, métrica)?
- Há prazo, risco ou restrição operacional relevante?
- Essa demanda precisa ser tratada como uma única tarefa, subtarefas ou issues separadas?

## Formato de Saída
Responda sempre neste formato:

### Demanda Consolidada
<1-2 frases com objetivo operacional>

### Contexto Já Confirmado
- <item>

### Lacunas de Contexto
- <item>

### Perguntas Mínimas
- <pergunta>

### Decisões para Veto
- <decisão, descrita em termos de comportamento observável> | Alternativa: <outra opção> | Muda o comportamento da simulação: sim/não

### Simplificações do 5e
- <regra> | Simplificação adotada | Impacto na métrica: baixo/médio/alto

### Alcançabilidade e Dívida Conhecida
- Alcançável com: conteúdo real (seed/UI) | somente fixture de teste
- Dívida que distorce a métrica: <item ou nenhuma> | Vira tarefa: sim/não

### Escopo
- Dentro: <itens>
- Fora: <itens>

### Decomposição e Dependências
- Tarefa: <nome curto> | Objetivo: <resultado> | Depende de: <nenhuma ou tarefa anterior> | Bloqueia: <próximas tarefas ou nenhum>

### Critérios de Aceite
- <critério verificável>
- Invariante: <invariante aplicável> → teste que falha quando ela é sabotada: <teste>

### Encaminhamento
- Estado: Pronto para triagem | Aguardando resposta do usuário
- Próximo passo: <ação objetiva>

## Critério de Conclusão
Considere concluído quando houver informação suficiente para um agente de triagem classificar a demanda sem suposições críticas e, se necessário, quando a decomposição em tarefas menores já estiver clara o bastante para evitar ambiguidade de escopo.
Pare nesse ponto: não avance para implementação, edição de arquivos ou execução de comandos de mudança.
