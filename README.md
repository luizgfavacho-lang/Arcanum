# ARCANUM

RPG de ação em mundo aberto focado em magia — Unreal Engine 5.5, C++ + Gameplay Ability System,
visual pintado estilizado.

- Visão, regras e decisões: [`Docs/01-GDD.md`](Docs/01-GDD.md)
- Arquitetura: [`Docs/02-Arquitetura.md`](Docs/02-Arquitetura.md)
- Renderização estilizada e VFX: [`Docs/03-Renderizacao.md`](Docs/03-Renderizacao.md)
- Fatia vertical: [`Docs/04-FatiaVertical.md`](Docs/04-FatiaVertical.md)
- Roadmap: [`Docs/05-Roadmap.md`](Docs/05-Roadmap.md)
- Próximas tarefas: [`Docs/06-Tarefas.md`](Docs/06-Tarefas.md)

## Primeiros passos
1. Instale o UE 5.5 e o Git LFS (`git lfs install`).
2. Defina `UE_ROOT` (ex.: `C:\Program Files\Epic Games\UE_5.5`).
3. `pwsh Scripts/Build.ps1` → `pwsh Scripts/Test.ps1`.
4. Siga os passos manuais de [`Docs/04-FatiaVertical.md`](Docs/04-FatiaVertical.md) §4.

> Atenção: a cota gratuita de Git LFS do GitHub (1 GB) acaba rápido num projeto Unreal. Considere
> um plano de dados LFS pago, um servidor LFS próprio ou Perforce quando os assets crescerem.
