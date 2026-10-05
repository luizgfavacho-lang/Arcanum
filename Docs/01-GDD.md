# ARCANUM — GDD resumido

> Fonte de verdade dos **números**: `Data/*.csv`. Este documento descreve regras e intenções; se
> houver divergência, o CSV vale e este texto deve ser corrigido.

## 0. Perguntas bloqueantes e premissas adotadas

Só quatro decisões mudam a arquitetura. Até haver resposta, o projeto segue a premissa indicada
(todas são reversíveis sem reescrever sistemas).

| # | Pergunta | Premissa adotada |
|---|---|---|
| 1 | Mundo **feito à mão** (fixo) ou **procedural por semente**, como no mod? | Mundo fixo feito à mão com World Partition e PCG **no editor**. Variação por semente só em estruturas menores (ruínas, poços, acampamentos) em "slots" pré-posicionados. Com isso a "garantia de covis" fica trivial: os covis são posicionados à mão, e a distância máxima vira regra de level design. |
| 2 | Versão exata da engine e SO principal de desenvolvimento? | UE **5.5** (o `.uproject` aponta para 5.5; o código compila de 5.4 em diante, com `UE_VERSION_OLDER_THAN` onde a API mudou), Windows + Visual Studio 2022. |
| 3 | Coop online: Steam, EOS ou só LAN/IP direto? | Listen server via OnlineSubsystemNull (LAN/IP) até o marco M7; EOS no M7 (é multiplataforma e gratuito). Servidor dedicado fica fora do escopo. |
| 4 | Quem produz a arte (texturas pintadas, flipbooks, animação)? Equipe ou solo com assets externos? | Equipe pequena. O pipeline aceita placeholders (kits do Marketplace/Fab repintados) e o estilo vem do shader e do pós-processo. Flipbooks 2D são feitos à mão desde o M2. |

## 1. Visão

RPG de ação em terceira pessoa, mundo aberto, focado em magia. Single-player com coop opcional
para 1 a 4 jogadores. O jogador é um aprendiz de mago que domina cinco escolas (Eletricidade,
Fogo, Energia, Necromancia e Sangue), abre covis selados, derrota cinco chefes e atravessa a
Fenda até o Reino Arcano para enfrentar o Avatar Arcano.

**Pilares:**
1. Magia expressiva e combinável: escolas, sinergias, runas e talentos.
2. Exploração recompensada: estruturas, selos, segredos e lore.
3. Visual pintado à mão, com efeitos de magia espetaculares.
4. Progressão em cadeia: cada covil entrega a chave do próximo.

**Loops:**
- **30 s:** mirar, conjurar, reposicionar, gerenciar mana e recargas, combinar estados.
- **10 min:** explorar uma região, descobrir uma estrutura, abrir o primeiro baú (XP), coletar
  Manita, comprar com o Mago Errante.
- **Campanha:** Torre → Caverna de Cristal → Cripta → Santuário → Forja → Altar → Portal → Reino
  → Cidadela (cinco provas) → Avatar Arcano.

## 2. Escala e unidades

- **1 bloco do mod = 1 metro** (100 uu). Alcances, raios e distâncias foram mantidos.
- **Vida no estilo do mod:** o jogador começa com **20 de Vida** (1 ponto = "meio coração"). É isso
  que permite **preservar os números de dano** das magias (4–50) sem conversão.
- Mana base 100, regeneração base 3/s.

## 3. Personagem e progressão

### 3.1 Atributos (GAS — `UArcanumAttributeSet`)
Vida, VidaMáx, Mana, ManaMáx, RegenMana, PoderMágico (+1% de dano por ponto), VelocidadeDeConjuração
(divide as recargas), Armadura (−4% de dano por ponto, teto de 80%) e Afinidade por escola (0–10,
+3% de dano por nível). As constantes estão em `Config/DefaultGame.ini`
(`UArcanumCombatSettings`).

**Fórmula de dano** (`ArcanumDamageMath::ComputeSpellDamage`, coberta por testes):
`Base × Runas/Talentos × (1 + PM×1%) × (1 + Afinidade×3%) × [Maldição 1,2] × [Carga Arcana 1,25] × [Combo] × (1 − Armadura)`.

### 3.2 Mana
- Barra própria. A regeneração **pausa 3 s** após causar ou receber dano.
- Poções Pequena/Média/Grande (+25/+60/+120 de mana).
- Pão Arcano: Fluxo de Mana I (+1,5 mana/s por 20 s).
- Elixir Etéreo: enche a mana e dá Fluxo de Mana II (+3 mana/s) por 30 s.

### 3.3 Níveis 1–50 (`Data/Levels.csv`)
- XP por conjurar (1 por magia, com limite de 30 por minuto contra "farm"), por derrotar inimigos
  (`Enemies.csv`, coluna `XPReward`) e por explorar estruturas pela primeira vez (25 a 150).
- Curva: `XP(n→n+1) = round(50 × n^1,5)`. O total até o nível 50 é de ~120 mil.
- Bônus por nível: +0,8 de VidaMáx, +2 de ManaMáx, +0,05 de RegenMana e +1 de PoderMágico.
  No nível 50: ~59 PV e ~198 de mana.
- 1 ponto de habilidade a cada 5 níveis (10 no total).

### 3.4 Afinidade por escola (0–10)
Cada conjuração bem-sucedida da escola conta 1 uso. Para subir de A para A+1 são necessários
`20 × (A+1)²` usos (total de ~7.700 até o 10). Cada nível dá +3% de dano na escola. No nível 10:
conquista e −10% de custo nas magias da escola.

### 3.5 Passivas (escolha 1; troca com a Pedra do Esquecimento) — `Data/Passives.csv`

| Passiva | Bônus | Desvantagem |
|---|---|---|
| Alquimista | Poções +50% de duração; bebe 2× mais rápido | Não usa escudo |
| Explorador Arcano | Bússola para a estrutura inexplorada mais próxima; +1 item nos baús | −5% de dano fora de estruturas |
| Maré de Sangue | Abaixo de 50% de vida, até +40% de dano e de velocidade | Acima de 90% de vida, −10% de dano |
| Condutor | Raios curam 50% do dano e recarregam mana; cadeias saltam +1 alvo | −15% de velocidade na chuva |
| Sortudo Maldito | 10% de crítico triplo | 5% de falha que gasta o dobro de mana |
| Coveiro | Mortos-vivos ignoram você até serem atacados; +15% de dano necromântico | Animais fogem |
| Cabeça nas Nuvens | Planar segurando o pulo (4 de mana/s), sem dano de queda; +30% de dano de explosões | — (o custo de mana é a desvantagem) |
| Sanguessuga | Golpes corpo a corpo curam 8% do dano | Regeneração natural de vida −50% *(substitui "fome", que não existe no jogo)* |
| **Pavio Curto** | Recargas −25% | Custo de mana +15% |
| **Pele de Pedra** | +6 de armadura; imune a empurrões | −15% de velocidade |
| **Sorte do Minerador** | 25% de chance de minério extra; +30% de Manita por veio | −10% de mana máxima |
| **Lobo Solitário** | +20% de dano sem aliados ou servos a 20 m | Não pode invocar servos |
| **Dançarino do Vazio** | Dash de 6 m (recarga de 8 s) com 0,2 s de invulnerabilidade | −10% de vida máxima |
| **Coletor de Almas** | Abates dão almas (até 20): +2% de PoderMágico por alma | Perde metade ao morrer; −10% de XP |
| **Fênix** | Renasce uma vez por dia do jogo com 50% da vida | Até poder renascer de novo, −20% de cura recebida |
| **Pavio de Mana** | +30% de mana máxima | Ao zerar a mana, sofre dano de 25% da vida máxima |

### 3.6 Árvore de Talentos — `Data/Talents.csv`
São 5 ramos (um por escola) com 5 nós cada: nós 1–2 são livres, 3–4 exigem 1 ponto no ramo e o 5
exige 3. Com 10 pontos o jogador completa dois ramos. Reiniciar devolve os pontos e consome uma
Pedra do Esquecimento. Os talentos e números são os do prompt original e estão no CSV (Value1–3,
com o significado na coluna Notes). Cada talento concede a tag `Talent.<Escola>.<Id>`, que as
abilities consultam.

### 3.7 Runas (até 2 por cajado; a 3ª substitui a mais antiga) — `Data/Runes.csv`
Poder (+20% de dano, +20% de custo), Eficiência (−25% de mana), Celeridade (−20% de recarga), runas
de escola (+15% de dano na escola: Fogo, Tempestade, Arcana, Tumular e Sangue) e Vazio (−10% de custo
e −10% de recarga). Receita: Cristal de Mana + Tijolo Rúnico + catalisador da escola. Também
aparecem nos cofres dos covis.

### 3.8 Equipamentos
- Cajados por escola (gema animada; socket `Muzzle` define de onde as magias saem) e o Grimório.
- Artefatos: Anel da Celeridade (−10% de recarga), Amuleto da Pressa (+10% de VelocidadeDeConjuração),
  Talismã do Foco (+1 de RegenMana) e Pingente Astral (+40 de mana máxima e +10% de PoderMágico).
- Armaduras de Cristal Arcano (+armadura, −5% de custo de mana) e Ígnea (+armadura, imune a
  queimaduras leves).
- **Slots:** cajado, 2 artefatos, armadura (peça única). O equipamento usa o mesmo mecanismo de
  modificadores das runas (`IArcanumSpellModifierSource`).

## 4. Magias

### 4.1 Regras gerais
| Tier | Custo de mana | Dano | Recarga |
|---|---|---|---|
| T1 | 10–20 | 4–8 | 1–3 s |
| T2 | 30–50 | 10–18 | 6–12 s |
| T3 | 80–150 | 25–50 em área | 30–90 s |
| Suprema (T4) | 150 | conforme a magia | 120 s |

- **Recarga global** de 0,4 s entre magias. Magias canalizadas não têm recarga e duram enquanto o
  botão estiver segurado, drenando mana por segundo.
- Magias de Sangue podem custar **vida** em vez de mana (`HealthCostPct`); o custo nunca mata
  (é preciso sobrar ao menos 1 ponto de vida).
- 5 atalhos de magia (teclas 1–5 / botões do controle), troca rápida (roda do mouse / bumpers) e
  conjuração no gatilho (botão esquerdo / RT).
- A lista completa, com todos os números, está em `Data/Spells.csv` (42 magias). Valores que fogem da
  faixa do tier estão marcados com `[excecao: motivo]` na coluna Notes; o validador aceita apenas
  esses casos.

### 4.2 Magias supremas (nomes e visuais originais)
| Mecânica de origem | Nome no jogo | Escola | Visual |
|---|---|---|---|
| Coluna de luz solar atrasada (1,7 s; 28 de dano dividido) | **Veredito da Aurora** | Fogo | Círculo rúnico dourado que "fecha" como um relógio; a coluna desce em pinceladas verticais |
| Esfera que congela o tempo (raio 5; 4 s) | **Ampulheta Partida** | Energia | Bolha de vidro rachado, com areia violeta suspensa e projéteis presos no ar |
| Laser gigante carregado (48 m; 30 de dano) | **Lança do Firmamento** | Energia | Constelação que se alinha atrás do mago e dispara um feixe de tinta branca |
| Raio divino em todos a 40 m (18 de dano + paralisia) | **Coroa de Trovões** | Eletricidade | Coroa de nuvens sobre o mago; raios em "Y" caem em cada alvo |
| 18 linhas de almas (7 de dano cada + fraqueza) | **Rosa dos Lamentos** | Necromancia | Pétalas espectrais que se abrem em leque radial |
| Gancho de sangue que puxa (10 de dano) | **Anzol Carmesim** | Sangue | Corrente líquida com farpas que se cristalizam no impacto |

### 4.3 Estados
| Estado | Tag | Efeito |
|---|---|---|
| Carga Arcana | `State.ArcaneCharge` | Próximo golpe direto +25%; é consumida |
| Paralisia | `State.Paralyzed` | Velocidade 0 e não conjura. Chefes: duração ÷3 e imunidade de 6 s depois |
| Queimadura | `State.Burning` | Dano periódico a cada 0,5 s; reaplicar renova a duração (não acumula) |
| Sangramento | `State.Bleeding` | Dano periódico; ×2 enquanto o alvo se move |
| Maldição | `State.Cursed` | +20% de dano recebido |
| Molhado | `State.Wet` | Vem da chuva ou da água; habilita combos |
| Fraqueza | `State.Weakened` | −20% de dano causado |

### 4.4 Combos entre escolas — `Data/Combos.csv`
| Combo | Gatilho | Alvo com | Efeito |
|---|---|---|---|
| Condução | Eletricidade | Molhado | ×1,5 e paralisia garantida de 1 s; seca o alvo |
| Pira Profana | Fogo | Amaldiçoado | ×1,3; a queimadura fica verde e salta para 1 alvo a 4 m |
| Vapor | Fogo | Molhado | ×0,8; apaga e cria névoa (raio 4) que cega inimigos |
| Sobrecarga | Eletricidade | Carga Arcana | +1 salto de cadeia (além do +25%) |
| Sangue Fervente | Sangue | Queimando | Sangramento ×1,5 |
| Colheita | Necromancia | Sangrando | Drenagem cura 100% |
| Fusão | Fogo | Paralisado | ×1,3 |
| Contenção | Energia | Paralisado | Prisão de Energia dura ×1,5 |

### 4.5 Conjuração (feedback)
Pose com o cajado erguido → selo rúnico se abre na gema → faíscas espiralam para dentro → pulso de
luz na saída. Antecipação/ação/recuperação claras e hit-stop de 2 a 4 quadros nos impactos fortes
(T2+ com dano ≥ 10).

## 5. Inimigos (`Data/Enemies.csv`)

| Arquétipo do mod | Criatura original | Comportamento |
|---|---|---|
| Zumbi mago | **Necrótico Sussurrante** | Drena vida a distância; invoca 2 ossudos menores |
| Esqueleto mago | **Ossomante** | Bolas de fogo/energia; teleporta quando 3+ inimigos estão a 4 m |
| Explosivo elétrico | **Bulbo Tempestuoso** | Infla, avisa com um zumbido e explode em descarga em cadeia |
| Aranha bruxa | **Tecedeira Rubra** | Teias que deixam lento e sangrando; abaixo de 50% de vida, Hemorragia |
| Slime | **Gosma Arcana** | Divide-se em 2 menores; estoura em orbes de mana |
| Espectro de mana | **Espectro de Mana** | Atravessa paredes; rouba 10 de mana por toque |
| Andarilho do vazio | **Andarilho do Vazio** | Teleporta o alvo 6 m; abre mini-singularidades |
| — | **Sentinela Arcana** | Estátua que desperta quando o jogador abre o baú da ruína |
| — | Golem de Magma, Cultistas, Morcegos de Sangue | Inimigos de região e de covil |
| Reino | **Fogo-Fátuo Etéreo** | Pacífico; dá mana a quem estiver perto; pode ser engarrafado |
| Reino | **Tecelã do Vazio** | Setas do vazio que puxam e deixam lento; teleporta até quem foge |
| NPC | **Mago Errante** | Comerciante de poções, tomos, mapas e runas |

- **Elites:** 10% dos mobs mágicos ganham aura dourada, vida ×2, dano ×1,5 e loot ×2.
- **Escala de dificuldade:** `mult = 1 + min(0,6, dist_km × 0,12) + min(0,4, dias × 0,02)`, com teto de
  ×2,0. Aplica-se à vida e ao dano; o XP acompanha o multiplicador.

## 6. Mundo

### 6.1 Superfície
Biomas: Planalto Verdejante (início), Floresta de Bétulas Antigas, Pântano Cinzento (Necromancia),
Cordilheira Tempestuosa (Eletricidade), Ermos Vulcânicos (Fogo) e Vale Escarlate (Sangue). A Manita
aparece em veios subterrâneos e no interior de cavernas, e é refinada em Cristais de Mana.

**Estruturas:** Ruínas Arcanas (5 variantes, uma por escola), Obelisco (bênção de 5 min), Poço de
Mana (enche a mana), Acampamento do Mago Errante, Mina de Manita Abandonada, Torre do Mago e
Observatório Astral (no Reino). Descobrir uma estrutura dá conquista; o primeiro baú dá XP. Cada
estrutura tem ambiente sonoro e partículas próprios.

### 6.2 Cadeia de covis (portas de selo que não consomem a chave)
| Selo | Abre | Chefe | Recompensa |
|---|---|---|---|
| Torre (do Aprendiz Corrompido) | Caverna de Cristal | Golem de Cristal | Selo de Cristal |
| Cristal | Cripta do Necromante | Lich Rei | Filactério, Selo da Cripta |
| Cripta | Santuário da Tempestade | Arquimago Tempestuoso | Núcleo da Tempestade, Selo do Santuário |
| Santuário | Forja Vulcânica | Ferreiro Infernal | Molde da Forja, Selo da Forja |
| Forja | Altar de Sangue | Matriarca de Sangue | Cálice Carmesim, Selo do Altar |
| Altar | Portal Arcano | — | — |

**Ativação:** Arquimago (segurar o Selo da Cripta no altar), Ferreiro (oferecer um Lingote de Brasa),
Matriarca (oferenda de itens, ou só um Cristal de Mana durante a Lua de Sangue). Arena com coleira
de 12 m, música própria, vida ×(1 + 0,75 por jogador extra) e recarga de 5 min.

**Mecânicas de chefe (proposta):**
- **Aprendiz Corrompido** (minichefe): ilusões que repetem suas magias; ensina a ler telegraphs.
- **Golem de Cristal:** recebe 20% do dano com os cristais fechados. Os cristais se expõem por 5 s
  depois de uma investida contra um pilar ressonante, ou quando a Faísca acerta 3 cristais em
  sequência.
- **Lich Rei:** 3 filactérios na arena o deixam imune; cada um é destruído com dano de uma escola
  diferente.
- **Arquimago Tempestuoso:** a arena alaga (Molhado) e o combo de Condução vale contra o jogador;
  plataformas secas giram.
- **Ferreiro Infernal:** ondas de magma em anel e uma bigorna que "forja" armadura nele (+10 de
  armadura por carga). Fogo cura o Ferreiro; Pulso Arcano e Prisão de Energia quebram as cargas.
- **Matriarca de Sangue:** drena os jogadores ligados por corrente; enxames de morcegos; na Lua de
  Sangue fica mais forte, mas dá recompensa dupla.

### 6.3 Reino Arcano
Arquipélago de ilhas flutuantes em altitudes médias, com céu de noite eterna. A Cidadela fica isolada
no centro. Biomas: Planícies Etéreas, Bosque de Cristal e Ermos Fraturados (obsidiana chorona e
Astralita). A Fenda é despertada com as 4 Pedras-Chave (Selos da Cripta, do Santuário, da Forja e do
Altar). **Cidadela:** cinco provas (uma por escola, cada uma exige uma magia da escola sob uma
restrição) abrem a câmara do Avatar Arcano, que tem 5 fases (uma por escola) e deixa a Coroa do
Arcano. As ilhas são ligadas por pontes de luz, correntes de vento (planar) e portais fixos.

### 6.4 Eventos de mundo
- **Lua de Sangue** (1 a cada 8 noites): mais elites (20%), XP ×1,5 e névoa vermelha.
- **Tempestade Arcana** (aleatória, ~1 por dia): raios guiados que carregam Baterias Arcanas;
  aviso no HUD 30 s antes.
- **Ciclo dia/noite:** 1 dia do jogo = 40 min reais. A chuva aplica Molhado.

## 7. Portal Arcano (sistema-vitrine)
Conjure uma vez para a entrada e outra para a saída. Cada jogador tem até 3 pares; conjurar agachado
fecha todos. Os portais podem ficar no chão, no teto ou em paredes, sem limite de distância, com
visão ao vivo do outro lado. Criaturas e projéteis atravessam nos dois sentidos, com travessia
instantânea que conserva direção e velocidade. Portais de parede são atravessados só de andar contra
eles. Arquitetura em `02-Arquitetura.md` §7.

## 8. Itens, criação e economia
- **Recursos:** Manita → Cristal de Mana (Refinaria Arcana); Fragmentos de Mana (drop); Fragmento
  Astral → Lingote de Astralita; Essência Etérea (Fogo-Fátuo engarrafado); Seda do Vazio (Tecelã);
  Lingote de Brasa (Forja/Golem de Magma).
- **Estações:** Refinaria Arcana, Caldeirão Arcano (poções) e Condutor de Mana (armazena 500 de mana e
  transfere entre estações e jogadores).
- **Tomos:** em baús (por tier e escola), com o Mago Errante e no Grimório (pesquisa com Fragmentos).
- **Moeda:** Fragmentos de Mana. A Pedra do Esquecimento é vendida pelo Mago Errante (preço alto) ou
  criada com Astralita.

## 9. UI, conquistas e acessibilidade
- **HUD (CommonUI):** vida, mana (com indicador de regeneração pausada), barra de 5 magias com
  recarga, afinidade da escola atual, bússola do explorador, eventos ativos e barra de chefe.
- **Telas:** Grimório (equipar magias), Árvore de Talentos e status (nível, atributos, passiva).
- **Conquistas:** abas Magia, Exploração e Reino (lista em `05-Roadmap.md`, M9).
- **Acessibilidade:** intensidade de flashes e tremor de câmera (0–100%); modo daltônico (cada escola
  também tem uma **forma**: Eletricidade = zigue-zague, Fogo = gota, Energia = losango, Necromancia =
  crânio, Sangue = lua crescente); legendas; remapeamento completo (Enhanced Input User Settings).

## 10. Coop (1–4)
- Progressão do personagem (nível, magias, talentos, inventário) **por jogador**. Estado do mundo
  (estruturas exploradas, chefes derrotados, portas abertas) é **do anfitrião**.
- Portas de selo abrem para o grupo se um jogador tiver o selo. Loot de chefe é instanciado por
  jogador.
- Fogo amigo desligado; efeitos de cura e Chuva Rubra afetam aliados.

## 11. Lacunas encontradas e soluções

| Lacuna | Solução |
|---|---|
| "Fome/vigor" da Sanguessuga não existe fora do Minecraft | Desvantagem trocada por −50% na regeneração natural de vida |
| Vida do jogador não especificada | Escala do mod (20 PV) para preservar os números de dano |
| "−15% por salto": linear ou composto? | Composto (`× 0,85^n`), testado em `Arcanum.Damage.ChainFalloff` |
| Golem de Cristal é "minichefe" no §8 e chefe da Caverna no §9 | É o 1º dos cinco chefes (chefe menor, sem altar de ativação) |
| Proc de canalizadas a 10 ticks/s | `ProcChance` em canalizadas = chance **por segundo** |
| Servos com recarga de 3 s seriam infinitos | Limite de servos ativos por tipo (`MaxTargets`) |
| Mundo gerado vs. feito à mão | Ver pergunta 1 (§0) |
| Clima não especificado, mas citado (Condutor, Molhado) | Chuva por bioma + Tempestade Arcana |
| Paralisia em chefes trivializaria lutas | Duração ÷3 e 6 s de imunidade |
| Toque Mortal "com teto em chefes" sem valor | Teto de 40 de dano (`SecondaryDamage`) |
| Textos de UI e localização | String Tables em CSV (`Content/Text/`), PT-BR como idioma fonte |

## 12. Mudanças de balanceamento (e por quê)
- **Míssil Arcano:** 2 de dano por orbe (6 no total com 3 orbes), dentro da faixa T1. O talento Barragem
  (5 orbes) leva a 10, o que é aceitável para um talento.
- **Muralha de Chamas:** 2 de dano por tick de 0,5 s (= os 4/s originais).
- **Pulso Arcano:** 10 de dano (sem número no original) para caber no T2.
- **T2 de controle/buff** (Escudo, Prisão, Armadura de Brasas, Ritual, Corrente Carmesim, Toque
  Mortal) têm recargas de 15 a 45 s: recarga de 6 a 12 s tornaria esses efeitos permanentes.
- **Tempestade (12 × 5) e Chuva de Estrelas (10 × 9)** mantêm os números do mod: o total passa da faixa
  T3, mas os impactos se espalham pela área e um alvo raramente recebe mais de 30–40.
