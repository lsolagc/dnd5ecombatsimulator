# Navbar

Barra superior do portal: marca “D20 · SIM”, quatro seções e o seletor de tema.

- O consumidor fornece a seção ativa (`nav-link active` + `aria-current="page"`) e o tema escolhido.
- Seções, nesta ordem: Início, Personagens, Classes, Simulações. “Simulações” leva direto a Novo experimento.
- Seletor Claro / Escuro / Sistema é um `btn-group` `btn-outline-secondary`; o ativo ganha fundo `secondary`. Ele grava `data-bs-theme` no `<html>`.
- Borda inferior `border-hairline` em `border-color`; sem sombra. A marca é texto, não logo.
