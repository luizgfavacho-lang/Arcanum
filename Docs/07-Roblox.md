# ARCANUM no Roblox

> **Plataforma ativa desde 05/10/2026.** O projeto Unreal (raiz do repositório: `Source/`,
> `Content/`, `Config/`) fica pausado como referência. Design, números e regras continuam valendo:
> `Docs/01-GDD.md` e `Data/*.csv` são compartilhados.

## 1. O que muda em relação ao GDD

| Tema | Unreal (plano original) | Roblox (plano atual) |
|---|---|---|
| Linguagem | C++ + GAS | Luau (`--!strict`), código em texto via **Rojo** |
| Números | DataTables importadas dos CSV | `Data/*.csv` → `roblox/src/shared/Data/*.luau` (gerado por `roblox/tools/gen_data.py`) |
| Vida | Atributo do GAS | `Humanoid.Health` (escala do mod: 20) |
| Mana, Poder Mágico, Armadura | AttributeSet | `StatsService` (servidor); Mana/MaxMana espelhados como atributos do personagem |
| Estados | Tags `State.*` por GameplayEffect | `StatusService`; atributo `State_<Nome>` no Model para o cliente |
| Rede | GAS LocalPredicted | Servidor autoritativo; o cliente só pede (`CastRequest`) e desenha (`Vfx`) |
| Projéteis | Atores replicados | Simulados no servidor sem Parts (spherecast por passo); o cliente desenha o mesmo trajeto |
| Visual pintado (toon + contorno) | Pós-processo no GBuffer | **Não há shader customizado.** Estilo vem de texturas pintadas (SurfaceAppearance), paleta, `Atmosphere` + `Bloom` + `ColorCorrection`, e contorno com `Highlight` só em destaques (limite de ~31 simultâneos) |
| VFX | Niagara | `ParticleEmitter` (com flipbook), `Beam`, `Trail`, Parts Neon. Os presets de `Docs/03` §8 continuam como alvo |
| Portal Arcano | Visão ao vivo + streaming | **Simplificado:** teleporte instantâneo conservando direção e velocidade, com "véu" animado e prévia estilizada (sem ver o outro lado ao vivo) |
| Coop | 1–4, listen server/EOS | Nativo; servidores do Roblox. Lotação sugerida: 6 por servidor |
| Save | SaveGame | DataStore (ProfileStore) |
| Monetização | Jogo pago | Gratuito: passes (cosméticos, slots de save, aparência de cajados). **Nada que venda poder** |

### Regras de conteúdo do Roblox
- **Escola de Sangue:** visual estilizado (luz carmesim, cristais, gotas de luz), sem sangue
  realista ou gore. Nomes e mecânicas ficam.
- Sem violência gráfica: inimigos se desfazem em luz/fumaça ao morrer.
- Configurar o questionário de maturidade do jogo antes de publicar.

## 2. Arquitetura

```
roblox/
  default.project.json      Rojo: árvore do jogo
  rokit.toml                ferramentas (rojo, lune, selene, stylua)
  src/shared/   → ReplicatedStorage.Shared
    Data/*.luau             GERADO dos CSV (não editar)
    Math/                   DamageMath, ProgressionMath (puros, testados)
    Config/CombatSettings   constantes de combate
    SpellCatalog            comportamento de cada magia (equivale ao DA_Spell_*)
    Spells                  junta catálogo + números + textos
    Net                     remotes (nomes e contratos)
    Schools, States, Units, Signal
  src/server/   → ServerScriptService.Server
    init.server.luau        inicializa os serviços (init → start)
    Services/               World, Progression, Stats, Staff, Status, Damage, Spell, Enemy
    Spells/                 Context, Projectile, Hitscan, ChainLightning
    Combat/                 Targeting, Modifiers (runas/talentos/passiva), StaffBuilder (cajado por código)
  src/client/   → StarterPlayerScripts.Client
    Controllers/            ClientState, Camera (ombro), Input, Hud, Vfx (despacha eventos visuais)
    Vfx/                    Lib (primitivas/presets), Effects (clarão, onda de choque, círculo rúnico),
                            Lightning, Projectiles, LifeStream, Numbers, Staff (pose), Auras (estados)
  tests/                    Lune: `lune run tests` (regras/dados) e `lune run tests/smoke` (efeitos)
  tools/gen_data.py         CSV → Luau
```

**Fluxo de uma conjuração:** tecla → `CastRequest(slot, origem, ponto mirado)` → `SpellService`
valida (vivo, não paralisado, recarga, GCD, custo) → paga custo → `SpellState` (recargas) para o
dono → `Vfx Cast` para todos → `Projectile`/`Hitscan`/`ChainLightning` → `DamageService`
(DamageMath, escudo, carga arcana, regen) → `VfxFast Damage`.

## 3. Como rodar (Windows)

1. **Roblox Studio** instalado e logado.
2. **Rokit** (gerenciador das ferramentas): baixe `rokit-*-windows-x86_64.zip` em
   github.com/rojo-rbx/rokit/releases, extraia e rode `.\rokit.exe self-install`. Feche e abra o terminal.
3. Na pasta do projeto:
   ```powershell
   cd C:\Users\profl\Arcanum\roblox
   rokit install
   rojo plugin install
   rojo serve
   ```
4. No Studio: **Novo → Baseplate** (ou um lugar vazio). Na aba **Plugins → Rojo → Connect**.
5. Aperte **Play** (F5). O mapa de teste é gerado por código (`WorldService`).
6. Controles: **1–5** magias (4 é canalizada: segure), **clique** = magia selecionada, **roda** troca,
   **Q/Shift** esquiva, **G** abre o Grimório, **V** troca o ombro, **Alt** solta o mouse.
7. Ao terminar, salve o lugar (`.rbxl`) fora do Git; o código fica no repositório.

**Testes e dados:**
```powershell
lune run tests                       # regras + consistência dos dados (sem abrir o Studio)
python ..\Scripts\validate_data.py   # CSV válidos
python tools\gen_data.py             # regenera src/shared/Data depois de editar um CSV
stylua src tests                     # formatação
selene src                           # lint (gera roblox.yml na 1ª vez)
```

### Sons
Todos os eventos têm som (`src/shared/SoundCatalog.luau`), escolhidos na biblioteca oficial de efeitos
(contas **Roblox** e **ProSoundEffects**, nomes terminados em "(SFX)"; liberados para qualquer jogo):
conjuração e impacto por escola, magias específicas, inimigos (aviso, carga, bote, pavio do Bulbo,
pancada, cristais, rugido, gargalhada, morte por criatura), jogador (esquiva, esquiva perfeita, dano,
queda), nível e interface do Grimório. `Max` corta arquivos longos com fade.
Trocar um som: Studio → **Caixa de ferramentas → Áudio** → busque, botão direito → **Copiar ID do ativo**
e cole como número no evento correspondente.

## 4. Roadmap Roblox

| Marco | Entrega | Aceite |
|---|---|---|
| **R0 — Base** *(feito)* | Rojo, dados gerados, matemática testada, Stats/Status/Damage/Spell, 5 magias (Faísca, Bola de Fogo, Míssil Arcano, Corrente em Cadeia, Drenar Vida), inimigos parados, HUD, VFX por código | `lune run tests` verde; no Studio as 5 magias funcionam contra os inimigos do Sandbox |
| **R1 — Combate da fatia** | Lâmina de Sangue (corpo a corpo), IA dos inimigos (perseguir, atacar, Ossomante teleporta), morte estilizada, passiva Condutor, save com ProfileStore, Grimório (UI para equipar) | 2 jogadores no Studio (Test → 2 Players) sem dessincronia; progresso persiste |
| **R2 — Visual** | Paleta e iluminação finais, texturas pintadas (SurfaceAppearance), flipbooks 2D a 12 fps nos ParticleEmitters, hit-stop curto, telegraphs de área | 60 fps em PC médio e 30 fps em celular intermediário com 20 inimigos |
| **R3 — Torre e Caverna** | Região inicial modelada, Torre do Mago, Aprendiz Corrompido, Caverna de Cristal, Golem de Cristal, portas de selo | Fatia vertical de `Docs/04` adaptada |
| **R4 — Progressão completa** | Níveis 1–50, afinidade, talentos, runas, 16 passivas, Pedra do Esquecimento | Testes por talento numérico |
| **R5 — Arsenal e mundo** | 42 magias, combos, outros 4 covis, eventos de mundo, Mago Errante, criação | Campanha até o Altar |
| **R6 — Reino Arcano** | Portal (teleporte estilizado), ilhas, Cidadela, Avatar Arcano | Final jogável |
| **R7 — Lançamento** | Monetização ética, tutorial, celular/console, conquistas (Badges) | Publicado |

## 5. Próximas tarefas (sessões locais com Sonnet)
- ~~**RT-01 Grimório**~~ *(feito)*: tecla G; as 42 magias implementadas a partir das artes conceituais.
- ~~**RT-02 IA**~~ *(feito)*: ver §6.
- ~~**RT-03 Lâmina de Sangue**~~ *(feito: golpe em arco, sangramento, custa vida)*. Antes: tipo `Melee` no catálogo; custo em vida (já suportado); sangramento.
- **RT-04 Save:** ProfileStore com nível, XP, afinidades e slots.
- **RT-05 Passiva Condutor:** fonte em `Combat/Modifiers` (+1 alvo em Eletricidade) e cura/mana no
  `DamageService` quando o atacante tem a passiva.
- ~~**RT-06 Morte estilizada**~~ *(feito)*: o corpo se desfaz em luz da escola.

## 6. Combate e IA (como funciona)

**Jogador.** Esquiva (Q, Shift ou B): impulso curto aplicado pelo cliente + 0,35 s de invulnerabilidade
validada no servidor (`DodgeService`); recarga 0,9 s. Desviar de um golpe de verdade dentro da janela é
*esquiva perfeita*: +12 de mana. Números em `Config/CombatSettings`, regras em `Math/CombatMath`.

**Equilíbrio (poise).** Cada golpe direto soma dano ao equilíbrio da criatura; passou do limite
(`EnemyCatalog.Poise`), ela fica **atordoada** e o golpe que estava preparando é **interrompido**
("INTERROMPIDO!"), com 2,5 s de imunidade depois. Golpes grandes empurram criaturas leves (`Weight`).

**Corpos.** `Combat/CreatureBuilder` monta tudo por código: Ossomante (esqueleto de capuz e manto, olhos
em brasa), Gosmas (gelatina com núcleo e olhos), Bulbo (membrana elétrica flutuante com tentáculos) e
Golem (pedra, punhos e cristais). `client/Vfx/Creatures` dá vida: squash & stretch, flutuar, inchar,
cabeça seguindo o alvo e tranco ao apanhar.

**IA** (`Combat/EnemyBrain`, 10 Hz). Estados: Ocioso (passeia e olha em volta) → Alerta ("!", reage no
tempo dele, aponta e chama o bando) → Combate → Procura ("?", vai até onde te viu) → Volta (coleira,
regenerando) e Fuga (pouca vida, conforme a coragem). Cada criatura sorteia personalidade (reação,
agressividade, agilidade, coragem, velocidade, distância preferida). Visão em cone + audição de perto;
apanhar revela de onde veio o golpe.

| Criatura | Comportamento | Ataques |
|---|---|---|
| Ossomante | Mantém distância, anda de lado com pausas, contorna para achar ângulo, **desvia de projéteis** (passo ou teleporte), foge com pouca vida, zomba ao acertar | Bola de Fogo com mira antecipada; os agressivos disparam rajada de 2 |
| Gosma / Gosminha | Cerca o alvo junto com o bando (cada uma por um ângulo), saltita | **Bote** (agacha tremendo e salta), contato; divide em 2 que já nascem atrás do matador |
| Bulbo Tempestuoso | Flutua em zigue-zague | Incha e explode; **morto antes, estoura igual e fere todos — inclusive outras criaturas** |
| Golem de Cristal | Avança devagar, guarda posição | Pancada em área, **linha de cristais** até o alvo, mísseis teleguiados; com 50% de vida **enfurece** (ruge, mais rápido, pancada dupla) |
