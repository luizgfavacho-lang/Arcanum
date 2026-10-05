--!strict
-- Corrente em Cadeia (canalizada): enquanto o botao estiver segurado, a cada TickIntervalSeconds
-- drena mana, acha o 1o alvo na mira e salta para ate MaxTargets (+ExtraTargets) com queda
-- composta por salto. Damage no CSV = dano por segundo no 1o alvo; ProcChance = por segundo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DamageMath = require(Shared.Math.DamageMath)
local Net = require(Shared.Net)
local States = require(Shared.States)
local Units = require(Shared.Units)
local Services = script.Parent.Parent.Services
local StatsService = require(Services.StatsService)
local StatusService = require(Services.StatusService)
local Targeting = require(script.Parent.Parent.Combat.Targeting)
local Context = require(script.Parent.Context)

local vfxFast = Net.get("VfxFast")
local vfx = Net.get("Vfx")

local ChainLightning = {}

local function tickOnce(ctx: Context.Context, interval: number)
	local row = ctx.Spell.Row
	local muzzle = Targeting.muzzle(ctx.Caster)
	local first, hitPoint =
		Targeting.aimTrace(ctx.Caster, ctx.Origin, Context.direction(ctx), Units.meters(row.RangeMeters), 1.5)

	local points = { muzzle }
	if first then
		local targets =
			Targeting.chain(ctx.Caster, first, row.MaxTargets + ctx.Mods.ExtraTargets, Units.meters(row.RadiusMeters))
		for jump, target in targets do
			Context.damage(
				ctx,
				target,
				DamageMath.chainDamageAtJump(row.Damage * interval, jump - 1, row.FalloffPerJump)
			)
			Context.tryProc(ctx, target, interval)
			table.insert(points, Targeting.position(target))
		end
	else
		table.insert(points, hitPoint)
	end
	vfxFast:FireAllClients("Chain", { Caster = ctx.Caster, Points = points, School = row.School })
end

function ChainLightning.start(ctx: Context.Context)
	local row = ctx.Spell.Row
	local interval = if row.TickIntervalSeconds > 0 then row.TickIntervalSeconds else 0.1

	ctx.Caster:SetAttribute("Channeling", ctx.Spell.Id)
	task.spawn(function()
		while not ctx.Stopped do
			local stats = StatsService.get(ctx.Caster)
			if not stats or stats.Humanoid.Health <= 0 or StatusService.has(ctx.Caster, States.Paralyzed) then
				break
			end
			if not StatsService.trySpendMana(stats, row.ManaPerSecond * interval * ctx.Mods.CostMultiplier) then
				break
			end
			tickOnce(ctx, interval)
			task.wait(interval)
		end
		ctx.Stopped = true
		if ctx.Caster.Parent then
			ctx.Caster:SetAttribute("Channeling", nil)
		end
		vfx:FireAllClients("ChannelEnd", { Caster = ctx.Caster })
		if ctx.OnEnded then
			ctx.OnEnded()
		end
	end)
end

return ChainLightning
