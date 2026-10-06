--!strict
-- Zonas no chao que ferem por tempo. Hoje: a poca de lava da Lanca de Magma.
-- A poca abre onde a lanca termina (parede, chao ou fim do alcance, projetado no chao abaixo) e
-- dura DurationSeconds. Quem estiver dentro do raio SecondaryRadiusMeters leva SecondaryDamage a
-- cada TickIntervalSeconds (dano periodico: numeros somados no cliente).

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

local GROUND_PROBE = 60 -- fim do alcance no ar: procura o chao ate essa distancia abaixo
local BODY_HEIGHT = 7 -- diferenca de altura maxima entre o corpo e a poca

type Zone = {
	Ctx: Context.Context,
	Center: Vector3,
	Radius: number,
	Tick: number,
	Damage: number,
	NextTick: number,
	EndsAt: number,
}

local Hazard = {}

local zones: { Zone } = {}

-- Poca de lava no chao sob (ou em) `position`.
function Hazard.lavaPool(ctx: Context.Context, position: Vector3)
	local row = ctx.Spell.Row
	if row.DurationSeconds <= 0 or row.SecondaryDamage <= 0 then
		return
	end
	-- So o terreno/mapa conta como chao (criaturas e o conjurador nao).
	local ignore: { Instance } = { ctx.Caster }
	for model in StatsService.all() do
		table.insert(ignore, model)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local ground = Workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -GROUND_PROBE, 0), params)
	if not ground then
		return
	end
	local now = os.clock()
	local radius = Units.meters(row.SecondaryRadiusMeters)
	local tick = math.max(row.TickIntervalSeconds, 0.1)
	table.insert(zones, {
		Ctx = ctx,
		Center = ground.Position,
		Radius = radius,
		Tick = tick,
		Damage = row.SecondaryDamage,
		NextTick = now + tick,
		EndsAt = now + row.DurationSeconds,
	})
	vfx:FireAllClients("LavaPool", {
		Position = ground.Position,
		Radius = radius,
		Duration = row.DurationSeconds,
		Seed = math.random(1, 1e6),
	})
end

local function burn(zone: Zone)
	local ctx = zone.Ctx
	if not ctx.Caster.Parent then
		return
	end
	local school = ctx.Spell.Row.School
	for model in StatsService.all() do
		if Targeting.isHostile(ctx.Caster, model) then
			local offset = Targeting.position(model) - zone.Center
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if flat <= zone.Radius + 1 and math.abs(offset.Y) < BODY_HEIGHT then
				DamageService.applySpellDamage(ctx.Caster, model, zone.Damage, school, {
					Multiplier = ctx.Mods.DamageMultiplier,
					Periodic = true,
				})
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
				burn(zone)
			end
		end
	end)
end

return Hazard
