# Tarefas prontas para o Sonnet (M1)

Cada tarefa cabe numa sessão. Leia só os arquivos listados. Ao terminar: `Scripts/Build.ps1`,
`Scripts/Test.ps1` e marque a tarefa aqui. Não mude arquitetura; se precisar, pare e anote a dúvida.

### T-01 — Comandos de debug
- **Arquivos:** novo `Source/Arcanum/Private/ArcanumCheatManager.cpp/.h` (`UCheatManager`).
- **Fazer:** `arcanum.GiveSpell <Id>` (procura `DA_Spell_<Id>` pelo Asset Manager, `LearnSpell` e
  equipa no primeiro slot livre), `arcanum.SetAttr <Nome> <Valor>`, `arcanum.DumpSpell <Id>` (uma linha:
  linha do CSV + modificadores).
- **Aceite:** comandos funcionam em PIE; saída de 1 linha.

### T-02 — Progressão (nível/XP/afinidade)
- **Arquivos:** novo `Source/ArcanumCore/.../Components/ArcanumProgressionComponent.*`;
  `ArcanumPlayerState`; `ArcanumEnemyCharacter.cpp` (TODO de XP).
- **Fazer:** nível, XP, usos por escola (replicados, `COND_OwnerOnly`); `AddXP` usa
  `ArcanumProgressionMath::ApplyXP`; ao subir, aplica o bônus de `DT_Levels` com um GE infinito
  (`SetNumericAttributeBase` é aceitável no M1); afinidade sobe por `AffinityUsesToNext` e grava o
  atributo `Affinity<Escola>`. Inimigo morto chama `AddXP(GetXPReward())` no PlayerState do matador.
  Evento `OnLevelUp` para a UI.
- **Aceite:** teste novo `Arcanum.Progression.Component` (sem mundo: instanciar o componente com
  `NewObject` e chamar `AddXP`).

### T-03 — `UArcanumAbility_Hitscan` (Faísca, Drenar Vida)
- **Arquivos:** novo par em `Abilities/`; base `ArcanumGameplayAbility.h`; `ArcanumTargeting.h`.
- **Fazer:** `TraceAimTarget` com `RangeMeters`; dano `Damage`; `TryApplyProc`; se `HealFraction` > 0,
  `HealOwner(dano_estimado × HealFraction)` — use o dano **final** lendo a variação de vida do alvo
  antes e depois (`GetNumericAttribute`). Cue de impacto no ponto. Linha de raio = cue `Cast` com
  `Params.Location` = ponto de impacto.
- **Aceite:** Faísca paralisa ~20% das vezes (teste com 1000 rolagens via função pura de chance).

### T-04 — Passiva Condutor
- **Arquivos:** novo `ArcanumPassiveComponent` (implementa `IArcanumSpellModifierSource`), `DT_Passives`.
- **Fazer:** passiva escolhida (`FName`), concede tag `Passive.<Id>`. Condutor: `ExtraTargets += 1` em
  magias de Eletricidade. A cura e a mana **não** vão na `DamageExecution`: ficam em
  `UArcanumAttributeSet::HandleIncomingDamage`, quando o instigador tem `Passive.Conductor` e o spec
  tem `School.Electricity` (cura `BonusValue` × dano e devolve a mesma quantia em mana).
- **Aceite:** Corrente com Condutor salta para 5 alvos; teste do cálculo de cura.

### T-05 — IA Ossomante (StateTree)
- **Arquivos:** `ArcanumEnemyCharacter`, nova task de StateTree `ArcanumSTTask_CastSpell`.
- **Fazer:** inimigos usam o mesmo GAS: conceder `DA_Spell_Fireball` ao inimigo e ativar por tag.
  Teleporta 8 m quando 3+ hostis a 4 m (recarga 10 s).
- **Aceite:** Ossomante luta e foge; sem uso de Blueprint para lógica.

### T-06 — `UArcanumAbility_Melee` + Lâmina de Sangue
- **Fazer:** buff de `DurationSeconds` que concede `State.BloodBlade` e troca o ataque básico por
  golpes de `Damage` com sangramento; custo em vida via `HealthCostPct` (já suportado pela base).
- **Aceite:** custo de vida nunca mata (teste); golpe aplica `State.Bleeding`.

### T-07 — GameplayCue da Corrente em Cadeia
- **Arquivos:** novo `AGameplayCueNotify_Actor` em C++ (`ArcanumGCN_ChainLightning`).
- **Fazer:** em `WhileActive`, a cada 2 quadros: `TraceAimTarget` + `FindChainTargets` locais e
  atualizar 6–8 ribbons do `NS_Lightning` por salto (parâmetros de usuário `Start/End/Seed`).
- **Aceite:** visual igual no servidor e no cliente com 2 jogadores; ≤ 0,3 ms de game thread.

### T-08 — Escala de dificuldade
- **Arquivos:** `ArcanumEnemyCharacter.cpp` (TODO) + `UArcanumCombatSettings` (constantes).
- **Fazer:** fórmula de `01-GDD.md` §5 numa função pura em `Math/` + teste.
