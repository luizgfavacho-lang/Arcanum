# ARCANUM — contexto para o Claude Code

RPG de ação focado em magia (5 escolas, covis selados, coop). **Plataforma ativa: Roblox**
(pasta `roblox/`, Luau + Rojo). O projeto Unreal na raiz (`Source/`, `Content/`, `Config/`,
`Scripts/*.ps1`) está **pausado** — não mexa nele sem pedido explícito.
Docs em `Docs/` — leia só o que a tarefa pedir. Específico do Roblox: `Docs/07-Roblox.md`.

## Comandos (dentro de `roblox/`; saída curta)
- Testes: `lune run tests` (regras + dados) e `lune run tests/smoke` (cria todos os efeitos com
  instâncias reais do `@lune/roblox`: pega propriedade com nome/tipo errado sem abrir o Studio)
- Dados: `python ../Scripts/validate_data.py` → `python tools/gen_data.py` (CSV → `src/shared/Data`)
- Formatação: `stylua src tests` · Lint: `selene src`
- Jogo: `rojo serve` + plugin Rojo no Studio → Play

## Mapa (`roblox/`)
```
src/shared/  ReplicatedStorage.Shared: Data/ (GERADO), Math/ (puro, testado: Damage, Progression, ArmIK, CombatMath,
             ComboMath), Config/, SpellCatalog, Spells, Net (remotes e contratos), Schools, States, StaffPose,
             SoundCatalog (ids da biblioteca oficial do Roblox/ProSoundEffects), TextureCatalog (imagens publicas
             da Caixa de ferramentas: circulos magicos, aneis, flipbooks de fogo/fumaca, raios), Units, Signal
src/server/  ServerScriptService.Server: Services/ (World, Progression, Stats, Status, Damage,
             Spell, Enemy, Staff), Spells/ (Context, Projectile, Hitscan, ChainLightning, Area, Hazard, Zone, Barrage,
             Buff, Movement, Control, Beam, Flamethrower, Melee, Summon),
             Combat/ (Targeting, Modifiers, StaffBuilder, CreatureBuilder, EnemyCatalog, EnemyBrain,
             MinionBrain, RigAnimator, CollisionGroups)
src/client/  StarterPlayerScripts.Client: Controllers/ (ClientState, Camera, Input, Hud, EnemyBars, Vfx, Grimoire) e
             Vfx/ (Lib, Effects, Lightning, Projectiles, LifeStream, Numbers, Staff, HandIK, Auras, Audio,
             Creatures, DodgeAnim, MotorOverlay, SpellFx, ZoneFx, StrikeFx, Impact, FlameFx)
tests/       Lune (*.spec.luau + TestKit)
```
`Data/*.csv` (raiz) = fonte de verdade dos números; `Content/Text/ST_Spells.csv` = textos.

## Convenções
- `--!strict` em todo arquivo. Um módulo por arquivo; serviços expõem `init()` e `start()`.
- Identificadores em inglês; comentários e textos de UI em PT-BR.
- **Servidor decide tudo** (custo, recarga, dano, estados); o cliente só pede e desenha.
  Toda entrada do cliente é validada (`SpellService.sanitizeAim`).
- Nunca edite `src/shared/Data/*.luau`: mude o CSV e rode o gerador.
- Mudou regra de dano/mana/progressão? Atualize `Math/` + teste em `tests/`.
- Magia nova: linha no CSV (já existem as 42) + entrada no `SpellCatalog` + tipo em `src/server/Spells/`.
- Unidades no CSV em metros; converta com `Units.meters()` (1 stud = 0,28 m).
- Sem assets binários no Git: mapa de teste e VFX placeholder são gerados por código.

## Decisões tomadas (não rediscutir)
1. Roblox como plataforma; Unreal pausado (último estado: commit `c5957ca`).
2. Escala de vida do mod (jogador com 20) para preservar os números de dano.
3. Projéteis simulados no servidor sem Parts; o cliente desenha o mesmo trajeto.
4. Queda de cadeia composta (`×(1−f)^n`); proc de canalizadas é chance **por segundo**.
5. Recarga global de 0,4 s; canalizadas sem recarga e sem GCD.
6. Portal Arcano = teleporte estilizado (sem visão ao vivo do outro lado).
7. Escola de Sangue com visual estilizado (regras de conteúdo do Roblox).
8. Monetização sem vender poder.
9. Cajado preso ao HumanoidRootPart (não à mão); o cliente posiciona o braço direito por IK de dois
   ossos (`Shared/Math/ArmIK` + `client/Vfx/HandIK`, em `RunService.Stepped`) para a mão ficar sempre na
   empunhadura. A origem de TODA magia é `Shared/StaffPose.gemWorld(root, "Cast")`, igual no servidor e no cliente.

## Estado atual
- **R0 + polimento:** 5 magias contra inimigos (idle animado, viram para o jogador, morte que se desfaz em luz)
  num Sandbox com Terrain, árvores, ruína e cristais. Cajados estilizados com IK nas duas mãos, estocada
  com antecipação/mola, câmera de ombro esquerdo com tremor e kick de FOV, mira dinâmica com marcador de
  acerto, HUD completo (barras com trilha, slots com custo/recarga/falha, XP, nível), barras de inimigo e
  de chefe. Sem assistência de mira. Sons em todos os eventos (`SoundCatalog`, cortados por `Max`).
- **Grimório (G): as 42 magias jogáveis**, seguindo as artes conceituais. Tipos (`SpellCatalog.Kind`) e quem
  executa (`SpellService` CASTERS/CHANNELS): Projectile, Hitscan, ChainLightning, Beam, Flamethrower (canalizadas),
  Strike/Nova/Line (`Area`), Zone (Static/Wall/Vortex/Singularity/Rain/Hourglass), Barrage
  (Storm/Stars/Meteor/Verdict/Crown), Buff (ManaShield/EmberArmor/Sacrifice/Pact), Blink/Portal
  (`Movement`), Control (Prison/Hook/Chain/DeathTouch/Curse/Hemorrhage), Lance, Slash (`Melee`), Summon
  (servos com IA própria em `MinionBrain`, stats em `Enemies.csv`). Estados novos: Poisoned, EmberArmor,
  Empowered, Linked (com Value em `StatusService`). Muralha de Chamas bloqueia criaturas (`CollisionGroups`).
  Lança de Magma abre poça de lava irregular onde cai (`Spells/Hazard`, números no CSV). Cada magia tem detalhes
  próprios em `client/Vfx/SpellFx` (floreio na gema, resíduos, anéis, cúpula, nuvem, espinhos...).
- **Combate** (RT-02+): criaturas com corpo proprio (`Combat/CreatureBuilder`: esqueleto de capuz, gosmas
  gelatinosas, bulbo flutuante, golem de cristal) animadas no cliente (`Vfx/Creatures`). IA em
  `EnemyBrain`: estados Idle/Alert/Combat/Search/Return/Flee, personalidade por individuo, bando, flanco,
  desvio de magias; ataques telegrafados (bote, rajada, pancada, linha de cristais, explosao) que o
  equilibrio (poise) INTERROMPE; empurrao; chefe enfurece. Jogador: esquiva Q/Shift (passo arcano animado: `Vfx/DodgeAnim`) com invulnerabilidade
  e esquiva perfeita (+mana). Regras em `Math/CombatMath` (testado).
- **Modo de teste ligado:** `CombatSettings.DevInfiniteResources` (mana e vida infinitas) e `DevNoCooldowns` (magias sem recarga) = true. Desligar antes de publicar.
- **Reações entre escolas** (`Math/ComboMath`, aplicadas no `DamageService`): golpe direto de uma escola num alvo
  com certo estado → Sobrecarga (Fogo×Paralisado / Raio×Queimando: explode), Vaporizar (Fogo×Encharcado ×1,5),
  Condução (Raio×Encharcado: arcos para outros encharcados), Ruptura (Energia×Paralisado ×1,4, quebra a paralisia),
  Colheita (Necro×Sangrando: cura), Contágio (Sangue×Envenenado: espalha). Recarga de 0,6 s por alvo; Chuva Rubra
  encharca. Visual/texto/som em `client/Vfx/Impact` (+ hit-stop nas criaturas e clarão de tela nos golpes grandes).
- **Visual:** texturas de `TextureCatalog` (fogo e fumaça em flipbook, círculo mágico por escola via `Lib.groundDecal`
  em SurfaceGui com brilho, anéis de choque, arcos elétricos); gesto do cajado por tipo de magia (`Vfx/Staff`:
  Raise/Slam/Sweep/Thrust). Raio Arcano = feixe contínuo no cliente (`StrikeFx.arcaneBeam`, por quadro, segue a
  mira local) e drena ManaPerSecond (`StatsService.drainMana`; no modo de teste a mana é infinita).
  **Piromania** (id `InfernalVortex`, mantido por causa das tags da Unreal; substituiu o Vórtice Infernal) =
  lança-chamas canalizado em cone (`Spells/Flamethrower`: 8 m, 4 dano/s em cada alvo, queima, 18 mana/s) com jato
  contínuo em `Vfx/FlameFx`.
- `lune run tests` = 352 ok; `tests/smoke` valida efeitos, sons, cajado, mundo, HUD, Grimório, corpos das criaturas e reações. Polimento ainda não visto no Studio.
- Próximo: R1 — tarefas RT-03..RT-05 em `Docs/07-Roblox.md` §5.
