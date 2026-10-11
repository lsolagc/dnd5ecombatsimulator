D20 · SIM é um simulador de combate de D&D 5e para mestres de jogo: monta dois lados com personagens salvos, roda até 1000 combates e lê taxa de vitória, duração e impacto de mecânicas. É uma ferramenta de análise, sóbria e densa, em desktop primeiro, sem login, toda em português (pt-BR). O portal é Bootstrap 5.3 com a terracota da marca como `$primary`; tudo o que não é ação principal é a escala neutra do Bootstrap.

## Conteúdo e voz

- Escreva em pt-BR, frases curtas e diretas, sem ponto de exclamação e sem emoji. Trate o usuário por “você” implícito, no imperativo: “Monte a party”, “Escolha abaixo quem entra no Lado B”.
- Títulos e botões em caixa de frase: “Novo experimento”, “Repetir com ajustes”, “Baixar logs (JSON, .zip)”. Só o `eyebrow` vai em maiúsculas.
- Termos de jogo ficam como no D&D: nomes de features e manobras em inglês (“Second Wind”, “Maneuver: Precision Attack”); interface em português (“Ligado”, “Desligado”, “Restaurar ficha”).
- Números em formato brasileiro: “58,0%”, “21 de 50”, “82 ms”. Separe metadados com “ · ”: “Guerreiro · nível 4”.
- Gambits se escrevem “Alvo: condição → ação”: “Self: HP < 50% → Second Wind”.
- Estados vazios dizem o que fazer: “Nenhum combatente ainda. Escolha abaixo quem entra no Lado B.”
- Não invente métricas: mostre só o que o banco tem (ver brief).

## Cor

- Fundo `body-bg`, texto `body-color`, secundário `secondary-color`. Cartões aninhados em `tertiary-bg`. Separação só por borda de 1 px (`border-hairline`) em `border-color`: **sem sombras**.
- `primary` (terracota `#b3563c`) marca a ação principal de cada tela — uma só — mais o passo ativo do wizard, a barra de progresso e a borda de um campo editado. Texto sobre ela em `on-primary`.
- Texto terracota é `primary-text-emphasis` (sobre `body-bg`, `tertiary-bg`, `primary-bg-subtle`); nunca `primary` como texto no tema escuro.
- Destrutivo é `danger`; status “Ligado” é `success` e sempre leva a palavra.
- Erros em `danger-bg-subtle` / `danger-border-subtle` / `danger-text-emphasis`; avisos (experimento interrompido) no trio `warning-*`.
- **Identidade dos lados**: `side-a` (azul), `side-b` (laranja), `side-neutral` (sem vencedor). Marcam bordas, pontos e barras, **nunca texto**, e vêm sempre com a letra “A”/“B” ou um rótulo. `side-b` e `primary` são vizinhos: mantenha o botão principal longe dos cartões do Lado B.
- Temas Claro e Escuro via `data-bs-theme`, com o seletor Claro / Escuro / Sistema na navbar. Todos os tokens têm valor nos dois.

## Tipografia

- Uma só família: a stack de sistema do Bootstrap (`sans`). Sem fonte customizada, sem arquivo de fonte.
- Títulos em peso 700: `page-title` para o h1 de toda página, `headline` para a manchete do resultado, `side-title` e `card-title` dentro de painéis. `hero` só na home.
- `eyebrow` (MAIÚSCULAS, .12em) acima do h1 e do bloco de resultado, em `secondary-color`.
- Números de jogo em monoespaçada (`mono`): atributos, HP, CA, dados (`1d8`), seeds — estilos `stat` e `stat-line`. Contadores grandes (`big-number`, `tile-value`) seguem em sans, como hoje.
- Rótulos de campo do cartão do combatente em `field-label`.

## Espaço, forma e layout

- Spacers do Bootstrap: `space-1` … `space-5`; `space-card` (.75rem) entre cartões e `space-side` (1.25rem) no padding do painel de lado.
- Raios: `radius-panel` em painéis e tiles, `radius-card` em cartões internos, `radius-control` em botões e campos, `radius-pill` em chips, `radius-bar` nas pontas da barra de vitórias.
- Navbar com borda inferior, conteúdo em `container-fluid p-4`; simulações limitadas a `content-max`.
- Desktop em 1400 px (`artboard-desktop`), mobile em 390 px (`artboard-mobile`) sem rolagem horizontal. Abaixo de `breakpoint-md` os campos do cartão quebram em 2 colunas e a barra de execução rola com a página.

## Componentes

Os padrões já existentes no portal (navbar, cabeçalho de página, botões, painéis, stat tiles, cartões de contagem, tabelas expansíveis, chips, wizard, slots de gambit) e os das simulações (`.sim-*`: painel de lado, cartão do combatente, chip de defesa, barra de execução, elenco, progresso, barra de vitórias, tiles de métrica). Os previews recriam as classes do Bootstrap e do `application.scss` com os tokens; no app, o Bootstrap 5.3 já fornece `.btn`, `.form-control`, `.table` etc.

- Botões: `btn-primary` para a ação principal, `btn-outline-secondary` para navegação e secundárias, `btn-outline-danger` / `btn-danger` para destrutivas.
- Interações leves com Stimulus; progresso por Turbo Stream. Gráficos só com HTML e CSS (a barra de vitórias são `div`s). Sem React, sem biblioteca de ícones ou gráficos.

## Acessibilidade

- Rótulos visíveis em todo campo; foco de teclado com `focus-ring`.
- `aria-live` no progresso; barra de vitórias com texto alternativo.
- Cor nunca carrega sozinha o significado: lado com letra, “Ligado” com palavra, campo editado com “•” no rótulo.
- Pares da fonte abaixo de 4,5:1, mantidos e sinalizados nas notas: no tema escuro, o texto dos botões outline (`primary` 3,2:1, `secondary` 3,3:1, `danger` 3,4:1 sobre `body-bg`); `on-side-a` sobre `side-a` (4,4:1 / 3,6:1); o selo “B” branco sobre `side-b` (3,2:1 / 3,9:1); e o `focus-ring` a 25%. Em telas novas, prefira corrigir esses pares a copiá-los.

## Iconografia

Não há biblioteca de ícones nem logo. A marca é o nome “D20 · SIM” em `sans` negrito na navbar, nunca desenhado como símbolo. Os poucos glifos são caracteres de texto: `▸` (expandir linha), `⠿` (alça de arraste), `↑` `↓` (prioridade), `→` (gambit), `×` (remover), `●`/`○` (Ligado/Desligado).
