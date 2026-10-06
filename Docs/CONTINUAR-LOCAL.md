# Continuar o ARCANUM numa sessão local do Claude Code

Este arquivo resume a sessão na nuvem (claude.ai/code) para continuar no seu PC.
O contexto técnico completo e sempre atualizado está no `CLAUDE.md` da raiz (o Claude Code lê
sozinho ao abrir a pasta) e em `Docs/07-Roblox.md`. Aqui ficam o "como retomar", o histórico e o
que falta.

---

## 1. Preparar o PC (uma vez)

```powershell
cd C:\Users\profl\Arcanum
git fetch origin
git checkout claude/new-session-xl01k9
git pull origin claude/new-session-xl01k9
cd roblox
rokit install          # instala rojo, lune, stylua, selene (rokit.toml)
lune run tests         # deve dar 578 ok
lune run tests/smoke   # deve terminar com "SMOKE VFX: ok"
```

Instale o Claude Code (CLI ou app de desktop) e abra a pasta `C:\Users\profl\Arcanum`.
Depois cole o prompt da seção 2.

> Todo o trabalho está no branch `claude/new-session-xl01k9` (não há PR aberto). Se quiser,
> faça merge dele na `main` antes de continuar.

---

## 2. Prompt para colar na nova conversa

```
Estou continuando o projeto ARCANUM (RPG de magia no Roblox, pasta roblox/, Luau + Rojo + Lune).
Leia o CLAUDE.md da raiz e Docs/CONTINUAR-LOCAL.md antes de qualquer coisa. Responda sempre em
português. Eu testo no Roblox Studio (rojo serve + Play) e mando prints; você ajusta o código.
Regras: servidor decide tudo; números nos CSV de Data/ (rode Scripts/validate_data.py e
roblox/tools/gen_data.py, nunca edite src/shared/Data); regra nova em Math/ com teste; rode
`stylua src tests`, `lune run tests` e `lune run tests/smoke` antes de cada commit; não mexa no
projeto Unreal (Source/, Content/ exceto Content/Text/ST_Spells.csv, Config/).
Trabalhe no branch claude/new-session-xl01k9 (ou na main, se eu já tiver feito merge).
Próximo passo: <descreva aqui o que quer>.
```

---

## 3. O que já foi feito (em ordem)

1. **IA dos inimigos** (`Combat/EnemyBrain`): estados Ocioso/Alerta/Combate/Procura/Volta/Fuga,
   personalidade por indivíduo, bando, flanco, desvio de magias, ataques telegrafados, equilíbrio
   (poise) que interrompe golpes, empurrão, chefe que enfurece. Corpos próprios por código
   (`Combat/CreatureBuilder`) e animação no cliente (`Vfx/Creatures`).
2. **Combate do jogador**: esquiva Q/Shift com invulnerabilidade e esquiva perfeita (+mana),
   animação de passo arcano.
3. **Luz**: só a magia brilha (bloom alto nas partículas); personagens normais.
4. **Grimório (G)** com as 42 magias jogáveis, a partir das 5 artes conceituais.
5. **Sons** em todos os eventos (biblioteca oficial Roblox/ProSoundEffects), suavizados.
6. **Lança de Magma** abre poça de lava irregular e avermelhada onde cai.
7. **Reações entre escolas** (`Math/ComboMath`): Sobrecarga, Vaporizar, Condução, Ruptura,
   Colheita, Contágio; hit-stop e clarão de tela.
8. **Texturas públicas** (`Shared/TextureCatalog`): círculos mágicos, anéis, flipbooks de fogo e
   fumaça, raios. Gesto do cajado por tipo de magia.
9. **Raio Arcano** = laser roxo contínuo (aprovado pelo usuário), drena mana por segundo.
10. **Piromania** (substituiu o Vórtice Infernal; id interno `InfernalVortex`): lança-chamas
    canalizado, 8 m, queima (aprovado).
11. **Revisão das magias com referências de LoL/DotA** (`Math/SpellMath`, `Vfx/SignatureFx`):
    22 magias ganharam mecânica própria (tabela em `Docs/07-Roblox.md` §8) e indicador de mira no chão.
12. **Arena Arcana** (estilo Ratchet & Clank 2): coliseu flutuante em (0, 60, 900), portal ao lado
    do nascimento, rounds infinitos com dificuldade crescente, chefe a cada 5 rounds, coletáveis de
    vida e mana no centro, XP e recorde (`Services/ArenaService`, `Math/ArenaMath`, `Docs/07` §7).
13. **Mana máxima base 300**; vida e mana deixaram de ser infinitas.
14. **Nível** aumenta vida (+0,8) e mana (+10) máximas.
15. **Essências** (moeda estilo bolts): caem dos inimigos, quicam, são sugadas até o jogador;
    contador no canto. **Loja no Grimório** (100/300/900/2000 por círculo). Começa com as 5 básicas
    (Faísca, Bola de Fogo, Míssil Arcano, Drenar Vida, Lâmina de Sangue). (`Docs/07` §9)
16. Barra de vida padrão do Roblox (canto superior direito) desligada (`HudController`).

## 4. Preferências do usuário (aprendidas na sessão)

- Respostas em **português**, curtas e claras sobre o que mudou e como testar.
- Gosta de visual de magia forte, mas **sem estourar o bloom** (já reclamou de luz estourada);
  personagens com iluminação normal.
- Sons suaves (já pediu para diminuir).
- Testa sempre no Studio e manda print; ajustes visuais finos vêm de lá.
- Referências de jogo citadas: LoL, DotA, Ratchet & Clank (arena e bolts).

## 5. Pendências e ideias

- `CombatSettings.DevNoCooldowns = true` (magias sem recarga) ainda ligado; desligar antes de
  publicar.
- **Save (RT-04)**: nível, XP, Essências, magias liberadas e slots zeram ao sair
  (ProfileStore/DataStore).
- **Passiva Condutor (RT-05)**.
- 20 magias ainda sem mecânica própria nova (Corrente em Cadeia, Bola de Relâmpago, Coroa de
  Trovões, Míssil Arcano, Escudo de Mana, Prisão de Energia, Portal, Drenar Vida, Almas Errantes,
  Esqueleto, Exército, Rosa dos Lamentos, Ritual, Corrente Carmesim, Chuva Rubra, Hemorragia,
  Pacto...).
- Arena usa só Gosma, Ossomante, Bulbo e Golem (os outros inimigos do CSV ainda não têm corpo/IA).
- Muita coisa nova ainda **não foi vista no Studio** (Arena, Essências, loja, assinaturas das
  magias): esperar prints e ajustar.
- Selene (`selene src`) não rodava na nuvem (sem acesso à API do Roblox); rode localmente.

## 6. Ferramentas que ajudaram

- Achar sons: API da caixa de ferramentas
  `https://apis.roblox.com/toolbox-service/v1/marketplace/3?keyword=...` (criadores oficiais
  1 e 7462895450).
- Achar texturas: decalques públicos (`.../marketplace/13?keyword=...`); converter o ID do
  decalque para o ID da imagem procurando, com
  `https://economy.roblox.com/v2/assets/<id>/details`, o asset vizinho (ID um pouco menor) do
  mesmo criador com `AssetTypeId = 1`.
