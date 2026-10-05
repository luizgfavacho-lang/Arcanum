# ARCANUM — Fatia vertical (primeiro marco jogável)

Objetivo: provar **o combate de magia, o visual pintado e o loop de covil** em 20–30 min de jogo.

## 1. Escopo
| Área | Conteúdo |
|---|---|
| Mundo | 1 região de ~1 km² (Planalto Verdejante + borda da Floresta) em World Partition; PCG para vegetação, rochas e ruínas; 1 Ruína Arcana, 1 Poço de Mana, Acampamento do Mago Errante (só loja) |
| Estruturas | **Torre do Mago** (3 andares, minichefe Aprendiz Corrompido, dá o Selo da Torre) e **Caverna de Cristal** (interior em level streaming, porta de selo, chefe Golem de Cristal) |
| Magias (6) | Faísca, Bola de Fogo, Míssil Arcano, Drenar Vida, Lâmina de Sangue, Corrente em Cadeia |
| Inimigos | Ossomante, Gosma Arcana (divide), Bulbo Tempestuoso, Sentinela Arcana, Aprendiz Corrompido, Golem de Cristal |
| Progressão | Mana (regen com pausa, 2 poções), níveis 1–10, 1 passiva (**Condutor**, que conversa com 2 das 6 magias) |
| UI | HUD (vida, mana, 5 slots com recarga, barra de chefe, bússola simples), Grimório (equipar as 6 magias nos 5 slots), tela de status |
| VFX | Todos os da fatia no padrão final (§3) |
| Áudio | Assinatura de Fogo e Eletricidade, música exploração/combate/chefe, ambiente da Torre e da Caverna |
| Coop | Listen server com 2 jogadores (sem matchmaking) |

## 2. Magias da fatia — implementação
| Magia | Classe | Status do código | Falta |
|---|---|---|---|
| Bola de Fogo | `GA_Fireball` ← `UArcanumAbility_Projectile` | **Pronta** (C++) | BP com `ProjectileClass` = `BP_Proj_Fireball`; cue de impacto |
| Míssil Arcano | `GA_ArcaneMissile` ← `UArcanumAbility_Projectile` (`bHoming`) | **Pronta** (C++) | BP; `ProcStateTag` = `State.ArcaneCharge` no DA |
| Corrente em Cadeia | `UArcanumAbility_ChainLightning` | **Pronta** (C++) | Cue em loop `GCN_ChainLightning` (Actor) que desenha os fios |
| Faísca | `UArcanumAbility_Hitscan` | A fazer (T-03) | — |
| Drenar Vida | `UArcanumAbility_Hitscan` (`HealFraction`) | A fazer (T-03) | `NS_LifeStream` |
| Lâmina de Sangue | `UArcanumAbility_Melee` + buff | A fazer (T-06) | Arma temporária |

## 3. VFX no padrão final
| Efeito | Presets |
|---|---|
| Conjuração (todas) | `NS_SchoolSignature` + selo rúnico na gema + pulso de luz |
| Faísca | `NS_Lightning` (1 ramo) + `NS_Flash` pequeno |
| Bola de Fogo | `NS_ProjectileTrail` (fogo) + flipbook de explosão 12 fps + `NS_Flash` + brasas |
| Míssil Arcano | 3× `NS_ProjectileTrail` (energia) com auréola girando + estrela no impacto |
| Drenar Vida | `NS_LifeStream` alvo → mago |
| Lâmina de Sangue | Lâmina com fresnel + smear 2D por golpe + gotas de luz |
| Corrente em Cadeia | `NS_Lightning` com 6–8 fios trançados por salto, regenerados a cada 1–2 quadros |
| Golem de Cristal | `NS_Shockwave` (slam), cristais com fresnel, `NS_Flash` grande ao expor |

## 4. Passos manuais no editor (uma vez)
O código cria tudo que é texto; o editor precisa só ligar assets:
1. `pwsh Scripts/Build.ps1` e abrir o editor.
2. Criar `IA_Move` (Axis2D), `IA_Look` (Axis2D), `IA_Jump`, `IA_Spell1..5`, `IA_CastSelected`,
   `IA_CycleSlot` (Axis1D) e `IMC_Default` com as teclas WASD, mouse, Espaço, 1–5, botão esquerdo e
   roda. Pasta `/Game/Arcanum/Input`.
3. `BP_PlayerCharacter` (pai `AArcanumPlayerCharacter`): malha, AnimBP e os assets de input.
4. `BP_GameMode` (pai `AArcanumGameMode`): pawn = `BP_PlayerCharacter`.
5. `BP_Proj_Fireball`/`BP_Proj_ArcaneMissile` (pai `AArcanumProjectile`) com o Niagara do rastro.
6. `GA_Fireball`, `GA_ArcaneMissile` (pai `UArcanumAbility_Projectile`) e `GA_ChainLightning` (pai
   `UArcanumAbility_ChainLightning`) em `/Game/Arcanum/Spells/Abilities`.
7. Fechar o editor → `pwsh Scripts/ImportData.ps1`: cria os `DT_*` e os `DA_Spell_*` e liga
   `AbilityClass` quando existir `GA_<Id>`.
8. No `PlayerState` do BP (ou `BP_PlayerState`): `Spellbook.StartingSpells` = DAs da fatia.
9. `ProcStateTag` nos DAs: Fireball = `State.Burning`, ArcaneMissile = `State.ArcaneCharge`,
   ChainLightning e Spark = `State.Paralyzed`, BloodBlade = `State.Bleeding`.

## 5. Critérios de aceite
- [ ] 60 fps em RTX 3060 / 1080p / Alto com 20 inimigos e as 6 magias em uso; 30 fps estáveis em Baixo.
- [ ] Cada magia tem custo, recarga, dano e estado iguais ao `Spells.csv` (Functional Test `FT_Spells`).
- [ ] A regeneração de mana pausa 3 s após dano (teste) e a HUD mostra a pausa.
- [ ] A Corrente em Cadeia salta para até 4 alvos com −15% por salto, para ao soltar o botão e quando
      a mana acaba.
- [ ] A Torre entrega o Selo, a porta da Caverna abre sem consumir o Selo e o Golem só toma dano cheio
      com os cristais expostos.
- [ ] Do nível 1 ao 10 em ~25 min; passiva Condutor funcionando (cura e +1 salto).
- [ ] Coop com 2 jogadores: cada um vê as magias do outro com o visual completo; sem dessincronia de
      vida ou mana após 10 min.
- [ ] Toon, contorno e LUT ativos em todas as qualidades; flipbooks a 12 fps; flash de 1 quadro
      desligável.
- [ ] `Scripts/Test.ps1` verde; `validate_data.py --strict` verde.
