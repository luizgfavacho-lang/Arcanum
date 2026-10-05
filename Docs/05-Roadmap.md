# ARCANUM — Roadmap

Cada marco termina com: testes verdes, `validate_data.py --strict` verde, `CLAUDE.md` atualizado
(estado e decisões) e uma build jogável. As durações supõem uma equipe pequena (2–4 pessoas) e
servem só para ordenar o trabalho.

| Marco | Entrega | Critérios de aceite |
|---|---|---|
| **M0 — Fundação** *(este commit)* | Repositório, CLAUDE.md, módulos C++, GAS (atributos, ASC, custo, recarga, GCD, dano por escola), Projétil e Canalizada, Grimório, dados em CSV, scripts filtrados, testes de regras | Compila no UE 5.5; `Test.ps1` com 10 testes verdes; `ImportData.ps1` gera DT/DA sem erro |
| **M1 — Combate cinza** (3 sem.) | As 6 magias da fatia com placeholders; inimigo dummy e Ossomante com IA simples (StateTree); morte, XP e nível 1–10; passiva Condutor; comandos de debug | Functional Test `FT_Spells` cobre as 6 magias; 2 jogadores em listen server sem dessincronia |
| **M2 — Look de produção** (4 sem.) | `M_ArcanumMaster`, PP_Toon/Ink/Paint, LUT, céu pintado, presets de Niagara (§8 do guia), hit-stop, flipbooks | Comparação com o *style frame* aprovado; PP ≤ 1,2 ms; 40 efeitos ≤ 2,5 ms |
| **M3 — UI e Grimório** (2 sem.) | CommonUI: HUD, Grimório, status, opções de acessibilidade (flash, tremor, daltonismo, legendas, remapeamento) | Tudo navegável por controle; textos via String Table |
| **M4 — Fatia vertical** (5 sem.) | Região de 1 km², Torre, Caverna de Cristal, Aprendiz Corrompido e Golem de Cristal, áudio da fatia | Todos os critérios de `04-FatiaVertical.md` |
| **M5 — Progressão completa** (4 sem.) | Níveis 1–50, afinidade, árvore de talentos (25 nós), runas, as 16 passivas, Pedra do Esquecimento, save (3 slots) | Testes para cada talento numérico; save/load preserva tudo do §8 da arquitetura |
| **M6 — Portal Arcano** (5 sem.) | Portais com visão ao vivo, travessia que conserva velocidade, parede/teto, streaming na saída, 3 pares | 2 jogadores atravessam portais a 5 km de distância sem tela de carregamento; ≤ 3 ms de GPU |
| **M7 — Rede de produção** (3 sem.) | Projéteis previstos no cliente, mira por TargetData, EOS (convites), escala de chefes por jogador | Com 150 ms de RTT, projétil aparece no frame do input; sem rubber-band em portais |
| **M8 — Arsenal completo** (6 sem.) | As 42 magias, 5 bases que faltam, combos (`DT_Combos`), todos os estados | Cada magia com teste funcional; tabela de combos coberta |
| **M9 — Mundo e covis** (10 sem.) | Biomas, todas as estruturas, eventos (Lua de Sangue, Tempestade Arcana), clima, os outros 4 covis e chefes, Mago Errante completo, criação e economia, conquistas | Campanha até o Altar jogável de ponta a ponta |
| **M10 — Reino Arcano** (6 sem.) | Fenda, ilhas, 3 biomas, Observatório, criaturas do Reino, Cidadela (5 provas), Avatar Arcano, Coroa | Final do jogo jogável; conquistas do Reino |
| **M11 — Polimento e lançamento** (6 sem.) | Balanceamento, performance (30 fps no Baixo), localização (EN), acessibilidade, QA | Zero crash em 8 h de soak test; metas de fps nas 4 qualidades |

## Conquistas (lista inicial para o M9)
- **Magia:** primeira magia de cada escola; primeira canalizada; primeira suprema; afinidade 10 em cada
  escola; níveis 10/25/50; primeira runa; 2 runas no mesmo cajado; 5 talentos num ramo; cada combo.
- **Exploração:** descobrir cada tipo de estrutura; explorar 25/50/100 estruturas; cada covil; cada
  chefe; sobreviver a uma Lua de Sangue; carregar uma Bateria na Tempestade Arcana; atravessar um
  portal a 1 km.
- **Reino:** entrar no Reino; cada bioma do Reino; cada prova da Cidadela; derrotar o Avatar; engarrafar
  um Fogo-Fátuo; segredos (3 ocultos).
