--!strict
-- Zonas no chao que ferem por tempo. Hoje: o caminho de lava da Lanca de Magma.
-- O caminho segue o trajeto do projetil: cada trecho acende quando a lanca passa por cima
-- (distancia / velocidade) e dura DurationSeconds a partir dai. Quem estiver sobre um trecho aceso
-- leva SecondaryDamage a cada TickIntervalSeconds (dano periodico: numeros somados no cliente).
-- Largura: SecondaryRadiusMeters de cada lado do trajeto.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Units = require(Shared.Units)
local Services = script.Parent.Parent.Services
local DamageService = require(Services.DamageService)
local StatsService = require(Services.StatsService)
local Targeting = require(script.Parent.Parent.Combat.Targeting)
local Context = require(script.Parent.Context)

local vfx = Net.get("Vfx")

local SAMPLE_STUDS = 3 -- distancia entre pontos do caminho
local GROUND_PROBE = 16 -- altura maxima do trajeto acima do chao para deixar lava
local BODY_HEIGHT = 7 -- diferenca de altura maxima entre o corpo e o chao do trecho

type Zone = {
	Ctx: Context.Context,
	Points: { Vector3 },
	LitAt: { number }, -- instante em que cada ponto acende
	Duration: number,
	HalfWidth: number,
	Tick: number,
	Damage: number,
	NextTick: number,
	EndsAt: number,
}

local Hazard = {}

local zones: { Zone } = {}

local function lit(zone: Zone, i: number, now: number): boolean
	local t = zone.LitAt[i]
	return t ~= nil and now >= t and now <= t + zone.Duration
end

-- Caminho de lava sob o trajeto reto de um projetil.
function Hazard.lavaTrail(ctx: Context.Context, from: Vector3, direction: Vector3, length: number, speed: number)
	local row = ctx.Spell.Row
	if row.DurationSeconds <= 0 or row.SecondaryDamage <= 0 then
		return
	end
	-- Paredes cortam o caminho; criaturas nao (a lanca as atravessa).
	local ignore: { Instance } = { ctx.Caster }
	for model in StatsService.all() do
		table.insert(ignore, model)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local dir = direction.Unit
	local wall = Workspace:Raycast(from, dir * length, params)
	local reach = if wall then (wall.Position - from).Magnitude else length

	local now = os.clock()
	local points: { Vector3 } = {}
	local delays: { number } = {}
	local d = 2
	while d <= reach do
		local above = from + dir * d
		local ground = Workspace:Raycast(above + Vector3.new(0, 1, 0), Vector3.new(0, -GROUND_PROBE, 0), params)
		if ground then
			table.insert(points, ground.Position)
			table.insert(delays, d / math.max(speed, 1))
		end
		d += SAMPLE_STUDS
	end
	if #points == 0 then
		return
	end
	local litAt = {}
	for i, delay in delays do
		litAt[i] = now + delay
	end
	local halfWidth = Units.meters(row.SecondaryRadiusMeters)
	table.insert(zones, {
		Ctx = ctx,
		Points = points,
		LitAt = litAt,
		Duration = row.DurationSeconds,
		HalfWidth = halfWidth,
		Tick = math.max(row.TickIntervalSeconds, 0.1),
		Damage = row.SecondaryDamage,
		NextTick = now + math.max(row.TickIntervalSeconds, 0.1),
		EndsAt = litAt[#litAt] + row.DurationSeconds,
	})
	vfx:FireAllClients("LavaTrail", {
		Points = points,
		Delays = delays,
		Width = halfWidth * 2,
		Duration = row.DurationSeconds,
		School = row.School,
	})
end

local function burn(zone: Zone, now: number)
	local ctx = zone.Ctx
	if not ctx.Caster.Parent then
		return
	end
	local school = ctx.Spell.Row.School
	for model in StatsService.all() do
		if Targeting.isHostile(ctx.Caster, model) then
			local position = Targeting.position(model)
			for i = 1, #zone.Points do
				local a = zone.Points[i]
				local b = zone.Points[i + 1] or a
				local active = lit(zone, i, now) or (zone.Points[i + 1] ~= nil and lit(zone, i + 1, now))
				if
					active
					and math.abs(position.Y - a.Y) < BODY_HEIGHT
					and Targeting.distanceToSegment(position, a, b) <= zone.HalfWidth + 1.2
				then
					DamageService.applySpellDamage(ctx.Caster, model, zone.Damage, school, {
						Multiplier = ctx.Mods.DamageMultiplier,
						Periodic = true,
					})
					break
				end
			end
		end
	end
end

function Hazard.start()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for i = #zones, 1, -1 do
			local zone = zones[i]
			if now > zone.EndsAt then
				table.remove(zones, i)
			elseif now >= zone.NextTick then
				zone.NextTick += zone.Tick
				burn(zone, now)
			end
		end
	end)
end

return Hazard
