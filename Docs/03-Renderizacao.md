# ARCANUM — Guia de renderização estilizada ("pintura em movimento")

> Referência de *linguagem visual*: animação pintada 2D/3D (como a de *Arcane*). **Nada** de
> personagens, lugares, logotipos, nomes ou assets de terceiros. Todo o conteúdo é original.

## 1. Decisão de pipeline
O toon shading é feito em **pós-processo sobre o GBuffer**, não com um shading model custom. Motivos:
1. Não exige fork da engine.
2. Funciona com Lumen (a GI entra antes da quantização).
3. Funciona em todas as qualidades.

O material dos objetos só pinta: albedo pintado, normal suave e máscaras. Quem decide as faixas de
luz é o post-process.

```
Material (albedo pintado, normal suave, máscaras R=rim G=ID de material B=AO pintado)
   └► GBuffer ─► Lighting (Lumen opcional) ─► PP_Toon (rampa de luz) ─► PP_Ink (contorno)
        ─► PP_Paint (grão de pincel/papel) ─► Bloom ─► LUT pintado ─► UI
```

## 2. Material mestre — `M_ArcanumMaster`
Parâmetros (instâncias `MI_*`):
- `T_Albedo_Painted`: pinceladas visíveis, pouco ruído de alta frequência, **sem** sombra pintada
  (a sombra vem da rampa).
- `T_Normal_Soft`: normal "pintada" (bake de uma malha alta suavizada + 30% de normal de pincelada).
- `T_Masks`: R = intensidade de rim, G = ID de material (0–1 em 8 níveis, lido pelo contorno), B = AO
  pintado.
- `ShadowTint` (frio, padrão `#3B4A7A`) e `LightTint` (quente, padrão `#FFE2B8`), lidos pelo PP via
  Custom Depth Stencil (stencil = família de material) para permitir paletas por região.
- `RimStrength`, `RimWidth`: escrevem no canal de Emissive somente nos personagens (stencil 1–3).
- Variantes por *Static Switch*: `Foliage` (two-sided + vento por vertex color), `Character`, `Prop`,
  `Water` (sem toon, usa `M_ArcanumWater`).

**Regra:** texturas de 1K para props, 2K para personagens e heróis, com texel density de 512 px/m.

## 3. PP_Toon — rampa de luz
1. Calcula `L = Luminance(SceneColor) / max(Luminance(BaseColor), ε)`, que é a luz recebida sem o
   albedo.
2. Amostra `T_LightRamp` (256×8; 1 linha por família de material) em `L`: **3 faixas suaves**
   (sombra, meia-luz, luz) com transições de 0,05 a 0,08 (bordas macias, não duras).
3. `Cor = BaseColor × lerp(ShadowTint, LightTint, Ramp) + Especular_quantizado + Emissive`.
4. Especular: só um "brilho de tinta" de 1 faixa nos metais e na água.
5. Céu e partículas aditivas (stencil 7) passam direto.

**Sombras coloridas:** o `ShadowTint` frio contra o `LightTint` quente dá o contraste do estilo, e a
rampa evita sombras pretas.

## 4. PP_Ink — contorno
- Detecção de borda (Sobel 3×3) em três fontes: **profundidade** (linear, normalizada pela
  distância), **normal** (ângulo > 35°) e **ID de material** (canal G de `T_Masks` gravado no Custom
  Stencil).
- Espessura: 1,5 px a 5 m até 0,6 px a 60 m (curva `C_InkWidth`); a linha some depois de 120 m.
- **Irregularidade:** a largura e a opacidade são moduladas por `T_InkNoise` (ruído de pincel em
  espaço de tela, deslocado em "dois" — troca a cada 2 frames de 24 fps = 12 fps) para a linha
  "ferver" como desenho.
- Cor da linha: 30% do albedo local + 70% de `#1E1A24` (nunca preto puro).
- Personagens (stencil 1–3) ganham +30% de espessura para a silhueta ficar legível.

## 5. PP_Paint — acabamento
- Filtro Kuwahara leve (raio 2) só em distâncias acima de 40 m: o fundo "vira pintura".
- Grão de papel/tela (`T_Canvas`, 512², multiplicado a 4%).
- Névoa volumétrica estilizada: `ExponentialHeightFog` com volumetric opcional + cartões 2.5D de
  névoa pintada e partículas de poeira em volume.

## 6. Céu
Matte painting em domo (`SM_SkyDome` + `M_SkyPainted` com 2 camadas de nuvens 2.5D em parallax lento)
e um sol/lua pintados que seguem a `DirectionalLight`. O Reino Arcano usa noite eterna, violeta
profundo com ciano e dourado, e estrelas cintilantes (o mesmo sprite de 4 pontas dos VFX).

## 7. Cor e LUT
- **Ambientes dessaturados** (saturação de −20% a −35% nas texturas) e **magias saturadas**.
- Paletas por escola (núcleo / halo / sombra do efeito):

| Escola | Núcleo | Halo | Acento | Forma (daltonismo) |
|---|---|---|---|---|
| Eletricidade | `#FFFFFF` | `#3FA9FF` | `#FFE14D` | zigue-zague |
| Fogo | `#FFF4D6` | `#FF8A1F` | `#FFB000` | gota |
| Energia | `#FFFFFF` | `#9B5CFF` | `#D9B8FF` | losango |
| Necromancia | `#EFFFF2` | `#3DFF8A` | `#1D7A4C` | crânio |
| Sangue | `#FFE6E6` | `#C8102E` | `#5A0010` | lua crescente |
| Reino Arcano | — | `#4B1E8C` | `#3CE6E6` / `#E8B94A` | — |

- **LUT pintado:** `T_LUT_Base` (gradação feita sobre screenshots-chave no Photoshop/Krita), mais LUTs
  de evento (Lua de Sangue, Tempestade Arcana, Reino) mesclados por `PostProcessVolume` com peso.

## 8. VFX — presets de Niagara reutilizáveis
Todos são **Niagara Systems parametrizados por escola** (`User.SchoolColorCore/Halo/Accent`,
`User.Scale`, `User.Intensity`). O `GameplayCue` lê a tag `School.*` em `AggregatedSourceTags` e
aplica a paleta da tabela acima (via `DA_SchoolVFXPalette`), o que dá a assinatura automática.

| Preset | Emissores | Uso |
|---|---|---|
| `NS_Flash` | núcleo branco (1 quadro) + auréola que expande + risco anamórfico horizontal + (opc.) raios girando | Impacto de projéteis, conjuração, explosões |
| `NS_Shockwave` | anel no chão (mesh em decal) + parede de luz que sobe da borda e apaga + estrelas correndo pelo anel | Nova, Pulso, Meteoro, aterrissagens |
| `NS_RuneCircle` | 2 camadas de runas girando em sentidos opostos + aro extra + pilares de luz + núcleo pulsante | Telegraph de área, Campo Estático, conjuração T3 |
| `NS_LifeStream` | fita ondulante (ribbon) A→B + contas de luz correndo | Drenar Vida, Corrente Carmesim, Almas |
| `NS_Beam` | fita dupla (halo + núcleo branco) + hélices girando + contas + estrela de impacto | Raio Arcano, Lança do Firmamento |
| `NS_Lightning` | raio ramificado (ribbon com pontos regenerados a cada 1–2 quadros) + 6–8 fios trançados | Faísca, Corrente em Cadeia, Coroa de Trovões |
| `NS_ProjectileTrail` | núcleo branco, halo, auréola girando, rastro contínuo que afina, cintilações | Todos os projéteis |
| `NS_SchoolSignature` | runas subindo em volta do mago; em cada acerto, estrelas + partícula da escola (brasas, faíscas, runas, almas, gotas de luz) | Toda conjuração e acerto |
| `NS_Shield` | malha esférica com fresnel na borda + núcleo suave + hexágonos pintados | Escudo de Mana, Prisão, Ampulheta |

**Partículas base (biblioteca `NE_*`):** brilho que encolhe, faísca com gravidade, brasa que sobe e
esfria para vermelho, língua de fogo (branca → cor → escura), fumaça (translúcida e separada do
aditivo), estrela de 4 pontas que gira e pisca, luz em espiral ascendente e runas flutuantes.

**Estilo 2D sobre 3D:** explosões e smears em flipbooks desenhados à mão (8×8, 2048²), tocados a
**12 fps** ("em dois"; módulo `SubUV` com `Frame Rate = 12` e interpolação desligada). Flash branco de
1 quadro nos impactos fortes, controlado pela opção de acessibilidade.

**Brilho:** toda partícula de luz é aditiva, com bloom forte (`Bloom Intensity 1,2`, threshold 1,0 e
convolution bloom só em Épico). A fumaça nunca é aditiva.

**Hit-stop:** `UArcanumHitStopSubsystem` (M2) aplica `CustomTimeDilation = 0,05` no atacante e no
alvo por 2–4 quadros (T2+, dano ≥ 10), escalado pela opção de tremor/flash.

## 9. Pipeline de texturas pintadas
1. Modelar em blocos grandes e legíveis (silhueta primeiro), com proporções exageradas de 10% a 20%.
2. Bake (AO, curvatura, normal suave) → Substance Painter ou ArmorPaint com *smart material* de
   pinceladas → retoque à mão no Krita/Photoshop.
3. Regras: luz pintada mínima no albedo (só oclusão de cavidade), 3 a 5 valores por material, borda
   de forma com pincelada clara (rim pintado leve).
4. Exportar `T_<Asset>_A` (sRGB), `T_<Asset>_N`, `T_<Asset>_M` (máscaras) e importar com o preset
   `TP_Painted` (mip bias −0,5 para preservar as pinceladas).

## 10. Escalabilidade
| Qualidade | Toon/Contorno | Lumen | Névoa volumétrica | Kuwahara | VFX |
|---|---|---|---|---|---|
| Baixo (30 fps) | Sim (Sobel só de profundidade + ID) | Não (GI estática) | Não (cartões 2.5D) | Não | 50% das partículas, sem refração |
| Médio | Sim | Não | Sim, em baixa resolução | Não | 75% |
| Alto (60 fps em RTX 3060) | Sim | Sim (Software) | Sim | Sim | 100% |
| Épico | Sim | Sim (Hardware RT opcional) | Sim | Sim | 100% + convolution bloom |

## 11. Orçamentos
- **PP total** (toon + ink + paint): ≤ 1,2 ms em 1080p no RTX 3060.
- **40 efeitos de magia simultâneos:** ≤ 2,5 ms de GPU. Limites por sistema: projétil ≤ 300
  partículas, explosão ≤ 1.500 (pico), canalizada ≤ 800. *Significance Manager* do Niagara reduz
  efeitos de outros jogadores e efeitos a mais de 30 m.
- **Overdraw:** flipbooks recortados (cutout UV); nada de quads de tela cheia além do flash (1 quadro).
- **Draw calls:** ≤ 3.500 em mundo aberto (HLOD + instancing de PCG).
