--!strict
-- Magias instantaneas pela mira: Faisca (raio + paralisia) e Drenar Vida (cura HealFraction do dano).
-- Faisca (Arc Lightning, Zeus/DotA): com MaxTargets > 1 o raio ramifica do alvo para os vizinhos a
-- RadiusMeters, com queda composta por salto (FalloffPerJump).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DamageMath = require(Shared.Math.DamageMath)
local Net = require(Shared.Net)
local Units = require(Shared.Units)
local Targeting = require(script.Parent.Parent.Combat.Targeting)
local Context = require(script.Parent.Context)

local vfx = Net.get("Vfx")

local Hitscan = {}

function Hitscan.cast(ctx: Context.Context)
	local row = ctx.Spell.Row
	local range = Units.meters(row.RangeMeters)
	local target, hitPoint = Targeting.aimTrace(ctx.Caster, ctx.Origin, Context.direction(ctx), range, 1.2)

	-- Ramificacoes (so a partir de um alvo atingido).
	local chain: { Model } = {}
	if target and row.MaxTargets > 1 then
		chain =
			Targeting.chain(ctx.Caster, target, row.MaxTargets + ctx.Mods.ExtraTargets, Units.meters(row.RadiusMeters))
	end
	local forks: { Vector3 } = {}
	for i = 2, #chain do
		table.insert(forks, Targeting.position(chain[i]))
	end

	vfx:FireAllClients(ctx.Spell.Def.Visual or "Bolt", {
		Caster = ctx.Caster,
		From = Targeting.muzzle(ctx.Caster),
		To = if target then Targeting.position(target) else hitPoint,
		School = row.School,
		Hit = target ~= nil,
		Forks = forks,
	})

	if not target then
		return
	end
	Context.damage(ctx, target, row.Damage) -- cura do Drenar Vida: Context.damage
	Context.tryProc(ctx, target)
	for i = 2, #chain do
		local delay = (i - 1) * 0.05
		local victim = chain[i]
		task.delay(delay, function()
			if Targeting.isHostile(ctx.Caster, victim) then
				Context.damage(ctx, victim, DamageMath.chainDamageAtJump(row.Damage, i - 1, row.FalloffPerJump))
				Context.tryProc(ctx, victim)
			end
		end)
	end
end

return Hitscan
