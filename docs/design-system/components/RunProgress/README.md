# RunProgress

Estado em andamento do experimento, atualizado ao vivo por Turbo Stream.

- Eyebrow “Na fila” (0 finalizadas) ou “Rodando”; número grande (`big-number`) + “/ N simulações finalizadas”.
- Estatísticas: tempo médio, ritmo (simulações/s) e restante; “—” enquanto não há dado.
- Barra em `primary` sobre `secondary-bg`, listrada enquanto roda; a largura anima entre atualizações.
- `aria-live="polite"` no painel. Ação única: “Interromper” (`btn-outline-danger`).
