# CombatantCard

Cartão de um combatente em Novo experimento: identidade, campos ajustáveis com o valor da ficha como padrão, defesas e o resumo dos gambits.

- O consumidor fornece o personagem (nome, classe · nível · HP máx.), os valores da ficha e os valores do experimento.
- Campos: HP inicial (1…máx., com “/máx.”), CA, Ataque, Dano (`NdM`), Tipo de dano. Valores em `mono`.
- Campo diferente da ficha: `is-edited` — rótulo em `primary-text-emphasis` com “ •”, borda `primary`. O cabeçalho mostra a pílula “N ajustes” e “Restaurar ficha”.
- Defesas num `details` com resumo (“nenhuma”, “R fogo · I veneno”) que abre os `DefenseChip`s.
- Gambits: resumo de leitura (`GambitSummary` curto) ou “Ação aleatória”, mais o link “Editar gambits”. O experimento grava uma cópia ao ser criado.
- Fundo `tertiary-bg`, borda esquerda de 3 px na cor do lado. Abaixo de 768 px os campos ficam em 2 colunas (Tipo de dano em largura total).
