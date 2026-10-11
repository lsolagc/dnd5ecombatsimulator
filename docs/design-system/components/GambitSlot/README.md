# GambitSlot

Linha editável de uma regra de gambit: alça de arraste, número, Ligado/Desligado, Alvo · Condição · [Valor] · Ação, Salvar, ↑/↓ e Remover.

- Até 6 slots, avaliados de cima para baixo. O consumidor fornece a regra, a posição e se ela está ligada.
- Ligado: `btn-success` com “● Ligado”; Desligado: `btn-outline-secondary` com “○ Desligado” e os campos esmaecidos.
- “Valor” só aparece em condições com limite (HP < X%, recurso ≥ X).
- ↑ do primeiro e ↓ do último ficam desabilitados. Só existe na tela de gambits do personagem; nas simulações use `GambitSummary`.
