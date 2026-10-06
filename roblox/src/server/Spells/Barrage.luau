--!strict
-- Golpes que vem do alto (Kind "Barrage"):
--   Storm    Tempestade: Count raios em DurationSeconds sobre a area mirada (RadiusMeters);
--            cada raio fere em SecondaryRadiusMeters.
--   Stars    Chuva de Estrelas: igual, com estrelas.
--   Meteor   Meteoro: aviso no chao, o meteoro cai e explode (Damage em RadiusMeters, queima).
--   Verdict  Veredito da Aurora: coluna solar apos EffectValue s; Damage dividido entre os alvos.
--   Crown    Coroa de Trovoes: coroa sobre a cabeca; raio em todos os inimigos no RadiusMeters.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Units = require(Shared.Units)
local Targeting = require(script.Parent.Parent.Combat.Targeting)
local Context = require(script.Parent.Context)
local Area = require(script.Parent.Area)

local vfx = Net.get("Vfx")

local FLAT = Vector3.new(1, 0, 1)
local BODY_HEIGHT = 2.5
local METEOR_FALL = 1.2 -- segundos entre o aviso e o impacto

local Barrage = {}

local function aimGround(ctx: Context.Context): Vector3
	local range = Units.meters(ctx.Spell.Row.RangeMeters)
	local _, point = Targeting.aimTrace(ctx.Caster, ctx.Origin, Context.direction(ctx), range, 0.5)
	return Area.groundBelow(point, ctx.Caster)
end

local function damageAround(ctx: Context.Context, center: Vector3, radius: number, amount: number): { Model }
	local victims = Targeting.hostilesInRadius(ctx.Caster, center + Vector3.new(0, BODY_HEIGHT, 0), radius + 1.5)
	for _, target in victims do
		Context.damage(ctx, target, amount)
		Context.tryProc(ctx, target)
	end
	return victims
end

-- Varios impactos espalhados na area ao longo do tempo.
local function rain(ctx: Context.Context, mode: string)
	local row = ctx.Spell.Row
	local center = aimGround(ctx)
	local radius = Units.meters(row.RadiusMeters)
	local impact = Units.meters(row.SecondaryRadiusMeters)
	local count = math.max(row.Count, 1)
	vfx:FireAllClients(
		"BarrageStart",
		{ Mode = mode, Position = center, Radius = radius, Duration = row.DurationSeconds, School = row.School }
	)
	for i = 1, count do
		task.delay(0.3 + (i - 1) * row.DurationSeconds / count, function()
			if not ctx.Caster.Parent then
				return
			end
			local angle = math.random() * math.pi * 2
			local point = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * math.sqrt(math.random())
			point = Area.groundBelow(point + Vector3.new(0, 6, 0), ctx.Caster)
			vfx:FireAllClients("BarrageHit", { Mode = mode, Position = point, Radius = impact, School = row.School })
			damageAround(ctx, point, impact, row.Damage)
		end)
	end
end

local function meteor(ctx: Context.Context)
	local row = ctx.Spell.Row
	local center = aimGround(ctx)
	local radius = Units.meters(row.RadiusMeters)
	vfx:FireAllClients(
		"MeteorWarn",
		{ Position = center, Radius = radius, Duration = METEOR_FALL, School = row.School, Caster = ctx.Caster }
	)
	task.delay(METEOR_FALL, function()
		vfx:FireAllClients("MeteorImpact", { Position = center, Radius = radius, School = row.School })
		for _, target in damageAround(ctx, center, radius, row.Damage) do
			local away = (Targeting.position(target) - center) * FLAT
			Area.push(target, (if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis) * 25 + Vector3.new(0, 20, 0))
		end
	end)
end

local function verdict(ctx: Context.Context)
	local row = ctx.Spell.Row
	local center = aimGround(ctx)
	local radius = Units.meters(row.RadiusMeters)
	local delay = if row.EffectValue > 0 then row.EffectValue else 1.5
	vfx:FireAllClients("VerdictWarn", { Position = center, Radius = radius, Duration = delay, School = row.School })
	task.delay(delay, function()
		local victims = Targeting.hostilesInRadius(ctx.Caster, center + Vector3.new(0, BODY_HEIGHT, 0), radius + 1.5)
		local share = row.Damage / math.max(#victims, 1)
		for _, target in victims do
			Context.damage(ctx, target, share)
			Context.tryProc(ctx, target)
		end
		vfx:FireAllClients("Verdict", { Position = center, Radius = radius, School = row.School })
	end)
end

local function crown(ctx: Context.Context)
	local row = ctx.Spell.Row
	local origin = Targeting.position(ctx.Caster)
	local victims = Targeting.hostilesInRadius(ctx.Caster, origin, Units.meters(row.RadiusMeters))
	table.sort(victims, function(a, b)
		return (Targeting.position(a) - origin).Magnitude < (Targeting.position(b) - origin).Magnitude
	end)
	vfx:FireAllClients("CrownStart", { Caster = ctx.Caster, Duration = 0.6 + #victims * 0.07, School = row.School })
	for i, target in victims do
		task.delay(0.35 + (i - 1) * 0.07, function()
			if Targeting.isHostile(ctx.Caster, target) then
				vfx:FireAllClients(
					"CrownBolt",
					{ Caster = ctx.Caster, To = Targeting.position(target), School = row.School }
				)
				Context.damage(ctx, target, row.Damage)
				Context.tryProc(ctx, target)
			end
		end)
	end
end

function Barrage.cast(ctx: Context.Context)
	local mode = ctx.Spell.Def.Mode
	if mode == "Storm" or mode == "Stars" then
		rain(ctx, mode)
	elseif mode == "Meteor" then
		meteor(ctx)
	elseif mode == "Verdict" then
		verdict(ctx)
	elseif mode == "Crown" then
		crown(ctx)
	end
end

return Barrage
