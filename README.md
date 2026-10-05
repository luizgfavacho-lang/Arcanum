# ARCANUM

RPG de ação focado em magia, com cinco escolas, covis selados e coop.

> **Plataforma ativa: Roblox** (`roblox/`, Luau + Rojo). Como rodar: [`Docs/07-Roblox.md`](Docs/07-Roblox.md) §3.
> O projeto Unreal 5.7 (raiz) está pausado como referência.

- Visão, regras e decisões: [`Docs/01-GDD.md`](Docs/01-GDD.md)
- Arquitetura: [`Docs/02-Arquitetura.md`](Docs/02-Arquitetura.md)
- Renderização estilizada e VFX: [`Docs/03-Renderizacao.md`](Docs/03-Renderizacao.md)
- Fatia vertical: [`Docs/04-FatiaVertical.md`](Docs/04-FatiaVertical.md)
- Roadmap: [`Docs/05-Roadmap.md`](Docs/05-Roadmap.md)
- Próximas tarefas (Unreal, pausado): [`Docs/06-Tarefas.md`](Docs/06-Tarefas.md)
- **Roblox (ativo):** [`Docs/07-Roblox.md`](Docs/07-Roblox.md)

## Primeiros passos (Unreal, pausado)
1. Instale o UE 5.7 e o Git LFS (`git lfs install`).
2. Defina `UE_ROOT` (ex.: `C:\Program Files\Epic Games\UE_5.7`).
3. `pwsh Scripts/Build.ps1` → `pwsh Scripts/Test.ps1`.
4. Siga os passos manuais de [`Docs/04-FatiaVertical.md`](Docs/04-FatiaVertical.md) §4.

> Atenção: a cota gratuita de Git LFS do GitHub (1 GB) acaba rápido num projeto Unreal. Considere
> um plano de dados LFS pago, um servidor LFS próprio ou Perforce quando os assets crescerem.
