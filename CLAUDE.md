# ARCANUM — contexto para o Claude Code

RPG de ação em mundo aberto focado em magia, em UE 5.7 (C++ + GAS). Visual pintado (toon por
post-process). Os docs completos estão em `Docs/` — leia só o que a tarefa pedir.

## Comandos (saída já filtrada; nunca cole log completo no contexto)
- Build: `powershell -ExecutionPolicy Bypass -File Scripts\Build.ps1` (padrão `ArcanumEditor Development`; requer `UE_ROOT`)
- Testes: `powershell -ExecutionPolicy Bypass -File Scripts\Test.ps1 [-Filter Arcanum.Damage]` (valida dados e roda Automation)
- Dados: `python3 Scripts/validate_data.py [--strict]` (sem engine, instantâneo)
- Importar CSV → DataTables/Data Assets: `powershell -ExecutionPolicy Bypass -File Scripts\ImportData.ps1` (editor fechado)
- Logs completos: `Saved/Logs/{Build,Tests,ImportData}.log` — use `Select-String`/`grep` neles.

## Mapa
```
Source/ArcanumCore/   framework de magia (GAS). Public/<Pasta>/X.h  ↔  Private/<Pasta>/X.cpp
  Abilities/  base, Projectile, Channel, ChainLightning, ArcanumTargeting
  Attributes/ AttributeSet      Components/ ASC, Spellbook, IArcanumSpellModifierSource
  Effects/    GEs em C++ + DamageExecution      Data/ structs de linha + SpellDefinition
  Math/       regras puras (testadas)           Settings/ CombatSettings (DefaultGame.ini)
  Private/Tests/  Automation Tests (Arcanum.*)
Source/Arcanum/       jogo: CharacterBase, PlayerCharacter, EnemyCharacter, PlayerState, GameMode
Data/*.csv            balanceamento (fonte de verdade dos números)
Content/Text/*.csv    String Tables (carregadas por LOCTABLE_FROMFILE, sem asset)
Config/Tags/*.ini     tags de conteúdo (recargas, cues, talentos, passivas)
Docs/                 01-GDD, 02-Arquitetura, 03-Renderizacao, 04-FatiaVertical, 05-Roadmap, 06-Tarefas
```

## Convenções
- Prefixos da Unreal (`U`/`A`/`F`/`E`/`I`), tudo com `Arcanum` (`UArcanumX`). Uma classe por arquivo.
- Identificadores, tags e ids em **inglês**; comentários e textos de UI em **PT-BR**.
- Assets: `DA_Spell_<Id>`, `GA_<Id>`, `BP_Proj_<Id>`, `DT_<Tabela>`, `NS_<Preset>`, `M_/MI_`, `T_<Asset>_{A,N,M}`,
  `IA_/IMC_`; pastas em `/Game/Arcanum/<Área>`.
- `SpellId` = nome da linha em `Spells.csv` = sufixo das tags `Cooldown.Spell.<Id>` e `GameplayCue.Spell.<Id>.{Cast,Impact}`.
- Unidades no CSV: metros e segundos (código converte ×100 para cm).
- Mudou regra de dano/mana/progressão? Atualize `Math/` + teste em `Private/Tests/`.
- Mudou coluna de CSV? Mude o struct `F*Row` junto (o validador acusa divergência).
- Blueprints só para montar conteúdo (malha, Niagara, som, referências). Lógica em C++.
- Código que usa API que mudou entre versões: `#if UE_VERSION_OLDER_THAN(5, 5, 0)`.

## Decisões tomadas (não rediscutir)
1. Uma ability C++ por **tipo** de magia; a magia concreta é o `UArcanumSpellDefinition` no `SourceObject` do spec.
2. GEs genéricos definidos em C++ com SetByCaller (custo, recarga, dano, DoT, estado, cura); nada de GE `.uasset` para regras.
3. Escala de vida do mod (jogador com 20 PV) para preservar os números de dano.
4. ASC do jogador no PlayerState (Mixed); criaturas com ASC próprio (Minimal).
5. Dano só no servidor; projéteis gerados no servidor (fase 1). Predição de projétil = M7.
6. Toon via post-process sobre o GBuffer (sem fork da engine); contorno Sobel por profundidade + normal + ID.
7. Queda de cadeia composta (`×(1−f)^n`); proc de canalizadas é chance **por segundo**.
8. Mundo fixo feito à mão + PCG no editor (premissa; ver `Docs/01-GDD.md` §0).
9. Recarga global de 0,4 s; canalizadas sem recarga e sem GCD.

## Estado atual
- **M0 concluído no código** (não compilado neste ambiente: ainda não houve build com a engine).
  Primeira ação numa máquina com UE: `Build.ps1` → corrigir erros → `Test.ps1` (10 testes).
- Próximo: M1 — tarefas T-01..T-08 em `Docs/06-Tarefas.md`.

## Perguntas em aberto (premissas em uso)
Mundo fixo vs. procedural; versão da engine; plataforma online (EOS no M7); quem produz a arte.
Detalhes em `Docs/01-GDD.md` §0.
