# SidePanel

Painel de um lado do combate: borda superior de 4 px na cor do lado, selo com a letra, título e contagem.

- Classe `sim-side--party_one` (A, `side-a`) ou `sim-side--party_two` (B, `side-b`); a cor vem de `--sim-side-color`.
- O consumidor fornece a lista: `CombatantCard`s em Novo experimento, `Roster` em Experimento.
- Vazio: caixa tracejada (`radius-card`) dizendo o que fazer. Seletor “+ Adicionar personagem…” no pé; personagens já no outro lado aparecem desabilitados.
- A cor nunca está no texto: título “Lado A”/“Lado B” e a letra no selo.
