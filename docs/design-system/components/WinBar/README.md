# WinBar

Resultado do experimento: manchete, barra 100% A / sem vencedor / B e legenda com percentuais e contagens.

- Manchete (`headline`) com o ponto do vencedor: “Lado B venceu 58,0% dos combates.” ou “Empate técnico: cada lado venceu 50,0% dos combates.”
- Barra de `div`s, altura 2.5rem, segmentos com `flex` proporcional, fresta `winbar-gap` e pontas `radius-bar`; segmentos zerados somem da barra mas ficam na legenda.
- Rótulo dentro do segmento: `on-side-a` / `on-side-b` / `on-side-neutral`.
- `role="img"` + `aria-label` com os três valores. A legenda repete tudo em texto.
- Interrompido: preceda de um `Alert` de aviso; nenhuma simulação terminou: troque barra e legenda por uma frase.
