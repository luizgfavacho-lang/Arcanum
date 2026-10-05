--!strict
-- Contexto de uma conjuracao + helpers comuns de dano e estado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DamageMath = require(Shared.Math.DamageMath)
local SpellsModule = require(Shared.Spells)
local Services = script.Parent.Parent.Services
local DamageService = require(Services.DamageService)
local StatusService = require(Services.StatusService)
local Modifiers = require(script.Parent.Parent.Combat.Modifiers)

export type Context = {
	Player: Player?,
	Caster: Model,
	Spell: SpellsModule.Spell,
	Mods: Modifiers.Modifiers,
	Origin: Vector3, -- origem da mira (cabeca/camera), atualizada durante canalizacao
	AimPoint: Vector3,
	Stopped: boolean,
	OnEnded: (() -> ())?,
}

local Context = {}

function Context.damage(ctx: Context, target: Model, baseDamage: number): number
	return DamageService.applySpellDamage(ctx.Caster, target, baseDamage, ctx.Spell.Row.School, {
		Multiplier = ctx.Mods.DamageMultiplier,
	})
end

-- Rola ProcChance e aplica o estado do catalogo. exposureSeconds > 0 = chance por segundo.
function Context.tryProc(ctx: Context, target: Model, exposureSeconds: number?)
	local row = ctx.Spell.Row
	local state = ctx.Spell.Def.ProcState
	if not state or row.ProcChance <= 0 then
		return
	end
	local chance = if exposureSeconds
		then DamageMath.chanceForExposure(row.ProcChance, exposureSeconds)
		else row.ProcChance
	if math.random() < chance then
		StatusService.apply(target, state, row.ProcDurationSeconds, {
			DamagePerSecond = row.ProcDamagePerSecond * ctx.Mods.DamageMultiplier,
			Source = ctx.Caster,
			School = row.School,
		})
	end
end

function Context.direction(ctx: Context): Vector3
	local dir = ctx.AimPoint - ctx.Origin
	return if dir.Magnitude > 1e-3 then dir.Unit else Vector3.zAxis
end

return Context
