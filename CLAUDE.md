# ARCANUM — contexto para o Claude Code

RPG de ação focado em magia (5 escolas, covis selados, coop). **Plataforma ativa: Roblox**
(pasta `roblox/`, Luau + Rojo). O projeto Unreal na raiz (`Source/`, `Content/`, `Config/`,
`Scripts/*.ps1`) está **pausado** — não mexa nele sem pedido explícito.
Docs em `Docs/` — leia só o que a tarefa pedir. Específico do Roblox: `Docs/07-Roblox.md`.

## Comandos (dentro de `roblox/`; saída curta)
- Testes: `lune run tests` (regras de dano/mana/progressão + consistência dos dados)
- Dados: `python ../Scripts/validate_data.py` → `python tools/gen_data.py` (CSV → `src/shared/Data`)
- Formatação: `stylua src tests` · Lint: `selene src`
- Jogo: `rojo serve` + plugin Rojo no Studio → Play

## Mapa (`roblox/`)
```
src/shared/  ReplicatedStorage.Shared: Data/ (GERADO), Math/ (puro, testado), Config/, SpellCatalog,
             Spells, Net (remotes e contratos), Schools, States, Units, Signal
src/server/  ServerScriptService.Server: Services/ (World, Progression, Stats, Status, Damage,
             Spell, Enemy), Spells/ (Context, Projectile, Hitscan, ChainLightning), Combat/ (Targeting, Modifiers)
src/client/  StarterPlayerScripts.Client: Controllers/ (ClientState, Camera, Input, Hud, Vfx)
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

## Estado atual
- **R0 (base) pronto no código:** 5 magias (Faísca, Bola de Fogo, Míssil Arcano, Corrente em Cadeia,
  Drenar Vida), inimigos parados no Sandbox gerado por código, HUD, VFX placeholder, nível/XP/afinidade
  (sem save). `lune run tests` = 122 ok. Ainda não testado dentro do Studio.
- Próximo: R1 — tarefas RT-01..RT-06 em `Docs/07-Roblox.md` §5.
