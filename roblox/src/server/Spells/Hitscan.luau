--!strict
-- Magias instantaneas pela mira: Faisca (raio + paralisia) e Drenar Vida (cura HealFraction do dano).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Units = require(Shared.Units)
local DamageService = require(script.Parent.Parent.Services.DamageService)
local Targeting = require(script.Parent.Parent.Combat.Targeting)
local Context = require(script.Parent.Context)

local vfx = Net.get("Vfx")

local Hitscan = {}

function Hitscan.cast(ctx: Context.Context)
	local row = ctx.Spell.Row
	local range = Units.meters(row.RangeMeters)
	local target, hitPoint = Targeting.aimTrace(ctx.Caster, ctx.Origin, Context.direction(ctx), range, 1.2)

	vfx:FireAllClients(ctx.Spell.Def.Visual or "Bolt", {
		Caster = ctx.Caster,
		From = Targeting.muzzle(ctx.Caster),
		To = if target then Targeting.position(target) else hitPoint,
		School = row.School,
		Hit = target ~= nil,
	})

	if not target then
		return
	end
	local dealt = Context.damage(ctx, target, row.Damage)
	Context.tryProc(ctx, target)
	if row.HealFraction > 0 and dealt > 0 then
		DamageService.heal(ctx.Caster, dealt * row.HealFraction)
	end
end

return Hitscan
