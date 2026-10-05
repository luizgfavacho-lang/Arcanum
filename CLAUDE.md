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
src/shared/  ReplicatedStorage.Shared: Data/ (GERADO), Math/ (puro, testado: Damage, Progression, ArmIK),
             Config/, SpellCatalog, Spells, Net (remotes e contratos), Schools, States, StaffPose,
             SoundCatalog (ids de som; vazios = silencio), Units, Signal
src/server/  ServerScriptService.Server: Services/ (World, Progression, Stats, Status, Damage,
             Spell, Enemy, Staff), Spells/ (Context, Projectile, Hitscan, ChainLightning),
             Combat/ (Targeting, Modifiers, StaffBuilder)
src/client/  StarterPlayerScripts.Client: Controllers/ (ClientState, Camera, Input, Hud, EnemyBars, Vfx) e
             Vfx/ (Lib, Effects, Lightning, Projectiles, LifeStream, Numbers, Staff, HandIK, Auras, Audio)
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
  de chefe. Sem assistência de mira. Sons: ganchos prontos, ids vazios em `SoundCatalog`.
- **Inimigos lutam** (RT-02): `server/Combat/EnemyCatalog` (o que cada um faz) + `EnemyBrain` (IA por
  0,1 s); telegraphs no cliente (`Effects.dangerZone`, eventos `EnemyTelegraph`/`Slam`/`Explosion`/`Blink`);
  HUD com bordas de dano e tela de morte.
- `lune run tests` = 128 ok; `tests/smoke` valida efeitos, cajado, mundo e HUD. Polimento ainda não visto no Studio.
- Próximo: R1 — tarefas RT-01, RT-03..RT-06 em `Docs/07-Roblox.md` §5.
