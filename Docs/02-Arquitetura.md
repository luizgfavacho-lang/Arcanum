# ARCANUM — Arquitetura técnica

## 1. Princípios
1. **Lógica em C++, dados em texto.** Blueprints servem para montar conteúdo (malha, Niagara, som) e
   ligar referências. Os números ficam em `Data/*.csv`, os textos em `Content/Text/*.csv` e as
   constantes em `Config/*.ini`.
2. **Uma ability por *tipo* de magia, não por magia.** `UArcanumAbility_Projectile` serve Bola de
   Fogo, Míssil Arcano, Lança de Magma...; a magia concreta vem do `UArcanumSpellDefinition` passado
   como `SourceObject` do spec.
3. **Regras puras e testáveis** em `Source/ArcanumCore/Public/Math/` (sem `UWorld`), cobertas por
   Automation Tests.
4. **Servidor autoritativo.** Clientes preveem ativação, custo e recarga (GAS LocalPredicted); o dano
   só é aplicado no servidor.

## 2. Módulos

| Módulo | Tipo | Conteúdo | Estado |
|---|---|---|---|
| `ArcanumCore` | Runtime (PreDefault) | Tags nativas, AttributeSet, ASC, abilities base, GameplayEffects em C++, ExecutionCalculation, Data Assets/linhas de tabela, matemática, projétil, Grimório, testes | **Criado** |
| `Arcanum` | Runtime (primário) | Personagens, PlayerState, GameMode, input | **Criado** |
| `ArcanumUI` | Runtime | Widgets CommonUI (HUD, Grimório, Talentos), ViewModels | M3 |
| `ArcanumWorld` | Runtime | Estruturas, selos, covis, eventos de mundo, clima, escala de dificuldade | M4 |
| `ArcanumPortal` | Runtime | Portais (render, travessia, streaming) | M6 |
| `ArcanumSave` | Runtime | SaveGame e serialização | M5 |
| `ArcanumEditor` | Editor | Validadores de dados, ferramentas de importação, comandos de debug do editor | quando necessário |

Regra de dependência: `Arcanum*` → `ArcanumCore`; nada depende de `Arcanum` (o módulo primário).
`ArcanumCore` não conhece UI, mundo nem portais.

## 3. Mapa de classes (implementadas)

```
ArcanumCore
├── ArcanumGameplayTags            tags nativas (School.*, State.*, Data.*, Cooldown.Global)
├── Data/
│   ├── EArcanumSchool + ArcanumSchool::ToTag/FromTags
│   ├── FArcanumSpellRow            ← Data/Spells.csv   (DT_Spells)
│   ├── FArcanumLevelRow            ← Data/Levels.csv   (DT_Levels)
│   ├── FArcanumEnemyRow            ← Data/Enemies.csv  (DT_Enemies)
│   ├── FArcanumRuneRow / TalentRow / PassiveRow / ComboRow
│   ├── FArcanumSpellModifiers      agregado de runas/talentos/passivas por conjuração
│   └── UArcanumSpellDefinition     (DA_Spell_<Id>) id, AbilityClass, linha de balanço, ícone, ProcStateTag
├── Attributes/UArcanumAttributeSet Vida, Mana, Regen, PoderMágico, VelConj, Armadura, Afinidade×5,
│                                   meta: IncomingDamage, IncomingHeal (escudo de mana, morte)
├── Components/
│   ├── UArcanumAbilitySystemComponent  regen de mana com pausa de combate, GatherSpellModifiers
│   ├── IArcanumSpellModifierSource     interface p/ runas, talentos, passiva, artefatos
│   └── UArcanumSpellbookComponent      aprendidas + 5 slots → GiveAbility(InputID = slot)
├── Abilities/
│   ├── UArcanumGameplayAbility         custo (mana/vida), recarga + GCD, dano, proc, cura, mira, cues
│   ├── UArcanumAbility_Projectile      N projéteis, leque, teleguiado, perfuração, explosão
│   ├── UArcanumAbility_Channel         segurar botão, drenagem por tick, fim ao soltar/sem mana
│   ├── UArcanumAbility_ChainLightning  cadeia com queda por salto
│   └── ArcanumTargeting                mira, hostilidade, vizinho mais próximo, cadeia, aplicar spec
├── Effects/  (GameplayEffects definidos em C++, sem .uasset)
│   ├── UArcanumDamageEffect     instantâneo → UArcanumDamageExecution
│   ├── UArcanumDotEffect        período de 0,5 s → UArcanumDamageExecution
│   ├── UArcanumStatusEffect     duração por SetByCaller + tag dinâmica
│   ├── UArcanumCostEffect       Mana/Vida por SetByCaller
│   ├── UArcanumCooldownEffect   duração por SetByCaller + tag dinâmica
│   ├── UArcanumHealEffect       IncomingHeal
│   └── UArcanumDamageExecution  captura PM/Afinidade (fonte) e Armadura (alvo) → ArcanumDamageMath
├── Actors/AArcanumProjectile    servidor-autoritativo, ímã de 0,6 m, explosão, cue de impacto
├── Math/ArcanumDamageMath, ArcanumProgressionMath   regras puras (testadas)
└── Settings/UArcanumCombatSettings  constantes globais (DefaultGame.ini)

Arcanum
├── AArcanumCharacterBase    IAbilitySystemInterface + IGenericTeamAgentInterface, morte, paralisia
├── AArcanumPlayerCharacter  câmera de ombro, Enhanced Input, 5 slots, conjurar selecionada, troca rápida
├── AArcanumEnemyCharacter   ASC próprio (Minimal), stats de DT_Enemies, elite 10%
├── AArcanumPlayerState      dono do ASC (Mixed) e do Grimório
└── AArcanumGameMode
```

### 3.1 Classes previstas (próximos marcos)
- `UArcanumAbility_Hitscan` (Faísca, Drenar Vida), `UArcanumAbility_GroundArea` (Raio Invocado, Meteoro,
  Tempestade: telegraph + atraso + área), `UArcanumAbility_SelfArea` (Nova, Pulso, Campo Estático),
  `UArcanumAbility_Summon` (servos com limite por tipo), `UArcanumAbility_Buff` (Escudo, Armaduras,
  Ritual, Pacto), `UArcanumAbility_Beam` (Raio Arcano), `UArcanumAbility_Melee` (Lâmina de Sangue).
- `UArcanumProgressionComponent` (PlayerState): nível, XP, afinidade (usos por escola), aplica
  `FArcanumLevelRow` como GE infinito de bônus.
- `UArcanumTalentComponent`, `UArcanumRuneComponent`, `UArcanumPassiveComponent`: implementam
  `IArcanumSpellModifierSource` e concedem tags `Talent.*`/`Passive.*`.
- `UArcanumComboSubsystem`: lê `DT_Combos` e é consultado pela `DamageExecution`.

## 4. Convenção de GameplayTags

| Raiz | Uso | Onde é definida |
|---|---|---|
| `School.<Escola>` | Escola da magia (asset tag dinâmica no spec de dano; cues) | Nativa |
| `State.<Estado>` | Estados concedidos por GE (`Paralyzed`, `Burning`, `Bleeding`, `Cursed`, `ArcaneCharge`, `Wet`, `ManaShield`, `Channeling`, `Dead`, `Weakened`) | Nativa (+ ini) |
| `Data.<Chave>` | Chaves de SetByCaller | Nativa |
| `Ability.Spell` | Asset tag de toda magia | Nativa |
| `Cooldown.Global` / `Cooldown.Spell.<Id>` | Recargas | Nativa / `Config/Tags/ArcanumSpells.ini` |
| `GameplayCue.Spell.<Id>.Cast` / `.Impact` | Visual e som de cada magia | `ArcanumSpells.ini` |
| `GameplayCue.Cast.School` | Assinatura automática de escola | Nativa |
| `Talent.<Escola>.<Id>` / `Passive.<Id>` | Concedidas pelos componentes de progressão | `ArcanumTalents.ini` |
| `Event.*` | Gameplay Events (AnimNotify de conjuração, hit, morte) | ini (M2) |

`<Id>` é o `SpellId` em inglês e PascalCase, igual ao nome da linha no CSV. As tags de recarga e cue
são **derivadas do SpellId** (`UArcanumSpellDefinition::GetCooldownTag()` etc.); os campos no Data
Asset existem só para casos especiais.

## 5. Fluxo de dados

```
Data/Spells.csv ──(Scripts/ImportData.ps1 → import_data.py)──► DT_Spells ─┐
                                                                         ├─► DA_Spell_<Id> (SpellId, Balance, AbilityClass*)
Content/Text/ST_Spells.csv ──(LOCTABLE_FROMFILE no StartupModule)──► ST_Spells (nome/descrição)
Config/Tags/*.ini ──► GameplayTags (recargas, cues, talentos)
Config/DefaultGame.ini ──► UArcanumCombatSettings (constantes)

Conjuração:
Input slot N ─► ASC.AbilityLocalInputPressed(N) ─► spec (SourceObject = DA_Spell)
  └► CheckCost/CheckCooldown (modificadores via IArcanumSpellModifierSource)
  └► CommitAbility: UArcanumCostEffect (SetByCaller) + UArcanumCooldownEffect (+ GCD)
  └► [servidor] MakeDamageSpec(SetByCaller Data.Damage, Data.DamageMultiplier, asset tag School.*)
        └► UArcanumDamageExecution ─► ArcanumDamageMath ─► IncomingDamage
              └► AttributeSet: Escudo de Mana → Vida → consome Carga Arcana → pausa regen → OnOutOfHealth
```
`*` AbilityClass é preenchida automaticamente se existir `GA_<Id>`.

**Validação:** `Scripts/validate_data.py` garante que as colunas dos CSV são iguais aos UPROPERTYs
dos structs, que os ids batem com a String Table e as tags, que a curva de níveis é igual à de
`ArcanumProgressionMath` e que os talentos e as faixas de tier estão corretos. Roda em CI
(`.github/workflows/data.yml`) e no início de `Test.ps1`/`ImportData.ps1`.

## 6. Replicação
- **ASC do jogador no PlayerState** (`Mixed`): sobrevive ao respawn, e o dono recebe os GEs completos
  (a HUD mostra as recargas). `NetUpdateFrequency` = 100.
- **ASC de criaturas no próprio ator** (`Minimal`): só tags e cues replicam.
- **Abilities `LocalPredicted`, `InstancedPerActor`.** Custo e recarga são previstos; dano, procs e
  spawn de projéteis só no servidor (`K2_HasAuthority`).
- **Canalizadas:** `WaitInputRelease` replica a soltura do botão; a drenagem e o dano rodam no
  servidor a cada tick. O visual é um cue em loop (`K2_AddGameplayCueWithParams`, previsto) que
  recalcula os saltos localmente com `ArcanumTargeting::FindChainTargets`.
- **Projéteis — fase 1 (implementada):** ator replicado gerado pelo servidor; o cliente vê o projétil
  com a latência da rede.
  **Fase 2 (M7):** projétil cosmético gerado no cliente no frame do input (`FPredictionKey`), com o
  servidor gerando o autoritativo adiantado em `RTT/2`. O cliente esconde o seu quando o
  autoritativo replica (associação por `PredictionKey` + índice), e a mira vai por `TargetData`
  (`UAbilityTask_WaitTargetData`) em vez dos olhos do pawn.
- **Mira:** fase 1 usa `GetActorEyesViewPoint` (rotação de controle replicada). Fase 2 envia o ponto
  da câmera via TargetData, com validação no servidor (ângulo máximo de 15° e distância do alcance
  + 10%).
- **Estados:** tags concedidas por GE replicam pelo ASC; reações (velocidade 0 na paralisia) rodam
  em todos via `RegisterGameplayTagEvent`.

## 7. Portal Arcano (sistema-vitrine) — desenho técnico
- **Ator `AArcanumPortal`** (par ligado): plano com `SceneCaptureComponent2D` + render target por
  portal **visível** (orçamento de 2 capturas ativas; os outros mostram a última captura em baixa
  resolução, a 15 fps).
- **Câmera virtual:** transformação `Saída · Rot180 · Entrada⁻¹` aplicada à câmera do jogador,
  com **clip plane oblíquo** (`bEnableClipPlane` + `ClipPlaneBase/Normal`, ou matriz de projeção
  oblíqua custom) para não renderizar o que está atrás da saída. A recursão é limitada a 1 nível
  (portal visto dentro de portal mostra a moldura com o shader de "véu").
- **Travessia:** componente de travessia nos atores relevantes (pawn, projéteis, criaturas). Quando
  o centro cruza o plano (sinal de `dot(Normal, Pos − Origem)` muda) dentro do retângulo, o ator é
  teletransportado com a mesma transformação, girando posição, rotação, velocidade e rotação de
  controle. O teleporte é autoritativo no servidor; o cliente prevê para o próprio pawn (o
  `CharacterMovementComponent` corrige com `ClientAdjust` se divergir).
- **Paredes e teto:** colisão do plano é desligada para quem está na zona de travessia (canal
  próprio), então andar contra a parede leva à travessia. Na saída, a gravidade é reorientada
  apenas na velocidade (o personagem sempre fica de pé).
- **Sem limite de distância:** `UWorldPartitionStreamingSourceComponent` em cada saída mantém as
  células em volta carregadas (raio de 64 m) enquanto o portal existir. Limite de 3 pares por
  jogador = até 6 fontes extras de streaming por jogador; com 4 jogadores, 24 no pior caso. Por
  isso só portais **vistos recentemente** (últimos 10 s) mantêm o streaming de visual; a travessia
  força o carregamento síncrono das células se necessário (com um "véu" de 0,2 s no pior caso).
- **Rede:** a posição dos portais replica; as capturas são locais (cada cliente renderiza a própria).

## 8. Save
`UArcanumSaveGame` (versionado, `int32 SaveVersion` + migrações):
- **Jogador:** nível, XP, afinidades e usos, magias aprendidas, slots, talentos, runas por cajado,
  passiva, inventário e portais (pares com transform e id de célula).
- **Mundo (anfitrião):** estruturas descobertas e exploradas (por `FGuid` do ator), selos usados,
  estado dos chefes (derrotado, timestamp da recarga), eventos, dia do jogo e semente das
  estruturas menores.
- Salvamento automático em estruturas, ao derrotar chefes e a cada 5 min; 3 slots.

## 9. Áudio, UI e input (resumo)
- **MetaSounds:** um "patch" por escola (assinatura) parametrizado por tier; música em camadas
  (exploração/combate/chefe) com crossfade pelo número de inimigos em combate; ambiente por
  estrutura via `AudioVolume`; legendas por `USoundWave` subtitles.
- **CommonUI:** HUD e telas em C++ com bindings em BP; ViewModels (MVVM plugin) para
  `Attributes`, `Spellbook` e recargas (consulta `GetCooldownRemainingForTag`).
- **Enhanced Input:** `IMC_Default` (teclado/mouse) e `IMC_Gamepad`; remapeamento por Player
  Mappable Keys.

## 10. Testes e diagnóstico
- **Unit (Automation):** `Arcanum.Damage.*`, `Arcanum.Mana.*`, `Arcanum.Progression.*` (já existem).
- **Functional Tests (M2+):** mapa `FT_Spells` com alvo dummy: conjura cada magia da fatia e checa
  dano, custo, recarga e estado aplicado.
- **Comandos de console (M2):** `arcanum.GiveSpell <Id>`, `arcanum.SetAttr <Attr> <Val>`,
  `arcanum.DumpSpell <Id>` (linha + modificadores em 1 linha de log), `arcanum.VFXStats` (contagem de
  sistemas Niagara ativos e custo em ms), `arcanum.Shot <nome>` (screenshot com HUD de debug).
  Saídas sempre resumidas.

## 11. Orçamentos de desempenho (alvo RTX 3060, 1080p, 60 fps)
| Item | Orçamento |
|---|---|
| Frame (GPU) | 14 ms (2,7 ms de folga) |
| Toon + contorno (post) | ≤ 1,2 ms |
| Niagara (40 efeitos simultâneos) | ≤ 2,5 ms GPU, ≤ 1 ms Game Thread |
| Portais (2 capturas) | ≤ 3 ms; capturas em 50% de resolução |
| Lumen | só em Alto/Épico; Médio = GI estática + AO pintado |
| Game thread | ≤ 10 ms com 60 IAs ativas (IA a mais de 40 m tica a 10 Hz) |
