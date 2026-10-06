--!strict
-- Areas com duracao (Kind "Zone"; numeros do CSV: Damage por tick, TickIntervalSeconds,
-- RadiusMeters, DurationSeconds, EffectValue):
--   Static       Campo Estatico (Plasma Field, Razor): segue o conjurador; pulso a cada Tick que
--                choca e paralisa, mais forte na borda (SpellMath.staticFieldMultiplier).
--   Wall         Muralha de Chamas: parede de RangeMeters no ponto mirado, perpendicular a mira;
--                bloqueia criaturas (grupo de colisao), queima quem a atravessa e apaga projeteis hostis.
--   Vortex       redemoinho que puxa (EffectValue m/s) e queima (sem magia usando no momento).
--   Singularity  Singularidade (Black Hole, Enigma): puxa forte por Duration, o miolo paralisa e
--                implode com Damage no fim.
--   Rain         Chuva Rubra: fere inimigos (Damage/s) e cura aliados (EffectValue/s).
--   Hourglass    Ampulheta Partida (Chronosphere): tempo parado (inimigos paralisados e vulneraveis,
--                projeteis hostis param).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local SpellMath = require(Shared.Math.SpellMath)
local States = require(Shared.States)
local Units = require(Shared.Units)
local Services = script.Parent.Parent.Services
local DamageService = require(Services.DamageService)
local StatsService = require(Services.StatsService)
local StatusService = require(Services.StatusService)
local Combat = script.Parent.Parent.Combat
local Targeting = require(Combat.Targeting)
local CollisionGroups = require(Combat.CollisionGroups)
local Context = require(script.Parent.Context)
local Area = require(script.Parent.Area)
local Projectile = require(script.Parent.Projectile)

local vfx = Net.get("Vfx")

local FLAT = Vector3.new(1, 0, 1)
local BODY_HEIGHT = 2.5
local WALL_CAST_RANGE = Units.meters(20) -- distancia maxima para erguer a muralha
local PULL_INTERVAL = 0.15

type Zone = {
	Id: string,
	Ctx: Context.Context,
	Mode: string,
	Center: Vector3,
	Radius: number,
	EndsAt: number,
	Tick: number,
	NextTick: number,
	NextPull: number,
	WallFrom: Vector3?,
	WallTo: Vector3?,
	Barrier: BasePart?,
}

local Zone = {}

local zones: { Zone } = {}

local function aimGround(ctx: Context.Context, range: number): Vector3
	local _, point = Targeting.aimTrace(ctx.Caster, ctx.Origin, Context.direction(ctx), range, 0.5)
	return Area.groundBelow(point, ctx.Caster)
end

local function hostilesIn(zone: Zone): { Model }
	return Targeting.hostilesInRadius(zone.Ctx.Caster, zone.Center + Vector3.new(0, BODY_HEIGHT, 0), zone.Radius + 1)
end

function Zone.cast(ctx: Context.Context)
	local row = ctx.Spell.Row
	local mode = ctx.Spell.Def.Mode or "Static"
	local now = os.clock()
	local radius = Units.meters(row.RadiusMeters)
	local center: Vector3
	if mode == "Static" then
		center = Area.groundBelow(Targeting.position(ctx.Caster), ctx.Caster)
	elseif mode == "Wall" then
		center = aimGround(ctx, WALL_CAST_RANGE)
	else
		center = aimGround(ctx, Units.meters(row.RangeMeters))
	end
	local zone: Zone = {
		Id = HttpService:GenerateGUID(false),
		Ctx = ctx,
		Mode = mode,
		Center = center,
		Radius = radius,
		EndsAt = now + row.DurationSeconds,
		Tick = if row.TickIntervalSeconds > 0 then row.TickIntervalSeconds else 0.25,
		NextTick = now + 0.05,
		NextPull = now,
		WallFrom = nil,
		WallTo = nil,
		Barrier = nil,
	}

	local payload: { [string]: any } = {
		Id = zone.Id,
		Mode = mode,
		Position = center,
		Radius = radius,
		Duration = row.DurationSeconds,
		School = row.School,
		Caster = ctx.Caster,
	}
	if mode == "Wall" then
		-- Perpendicular a linha conjurador -> ponto.
		local toWall = (center - Targeting.position(ctx.Caster)) * FLAT
		local forward = if toWall.Magnitude > 0.1 then toWall.Unit else Vector3.zAxis
		local side = forward:Cross(Vector3.yAxis)
		local half = Units.meters(row.RangeMeters) / 2
		zone.WallFrom = center - side * half
		zone.WallTo = center + side * half
		payload.From = zone.WallFrom
		payload.To = zone.WallTo
		-- Barreira invisivel que so as criaturas sentem.
		CollisionGroups.ensure()
		local barrier = Instance.new("Part")
		barrier.Name = "FlameWallBarrier"
		barrier.Anchored = true
		barrier.CanQuery = false
		barrier.CanTouch = false
		barrier.Transparency = 1
		barrier.Size = Vector3.new(half * 2, 9, 2)
		barrier.CFrame = CFrame.lookAt(center + Vector3.new(0, 4.5, 0), center + Vector3.new(0, 4.5, 0) + forward)
		barrier.CollisionGroup = CollisionGroups.SPELL_WALLS
		barrier.Parent = Workspace:FindFirstChild("ArcanumWorld") or Workspace
		zone.Barrier = barrier
	end
	table.insert(zones, zone)
	vfx:FireAllClients("Zone", payload)
end

local function pull(zone: Zone, speed: number)
	for _, target in hostilesIn(zone) do
		if not Players:GetPlayerFromCharacter(target) then
			local offset = (zone.Center - Targeting.position(target)) * FLAT
			local distance = offset.Magnitude
			-- Black Hole: no miolo da Singularidade ninguem se mexe.
			if
				zone.Mode == "Singularity"
				and SpellMath.inSingularityCore(distance, zone.Radius)
				and target:GetAttribute("Boss") ~= true
			then
				StatusService.apply(target, States.Paralyzed, PULL_INTERVAL + 0.15)
			end
			if distance > 1.5 then
				Area.push(target, offset.Unit * speed * math.clamp(distance / zone.Radius + 0.4, 0.4, 1.2))
			end
		end
	end
end

local function tick(zone: Zone, now: number)
	local ctx = zone.Ctx
	local row = ctx.Spell.Row
	local mode = zone.Mode
	if mode == "Wall" then
		local from, to = zone.WallFrom :: Vector3, zone.WallTo :: Vector3
		for _, target in Targeting.hostilesInRadius(ctx.Caster, zone.Center, (to - from).Magnitude / 2 + 4) do
			if Targeting.distanceToSegment(Targeting.position(target), from, to) <= 3.5 then
				Context.damage(ctx, target, row.Damage)
				Context.tryProc(ctx, target)
			end
		end
		-- Projeteis inimigos que cruzam a muralha viram cinza (Firewall).
		local burned: { Vector3 } = {}
		local length = (to - from).Magnitude
		for d = 0, length, 3 do
			local point = from:Lerp(to, if length > 0 then d / length else 0) + Vector3.new(0, 3, 0)
			for _, position in Projectile.destroyHostileNear(ctx.Caster, point, 3.5) do
				table.insert(burned, position)
			end
		end
		if #burned > 0 then
			vfx:FireAllClients("WallBurn", { Positions = burned, School = row.School })
		end
	elseif mode == "Hourglass" then
		for _, target in hostilesIn(zone) do
			StatusService.apply(target, States.Paralyzed, zone.Tick + 0.2)
			-- Fora do tempo, ficam vulneraveis (Maldicao: +dano recebido).
			StatusService.apply(target, States.Cursed, zone.Tick + 0.2, { Source = ctx.Caster })
		end
		Projectile.freezeHostile(ctx.Caster, zone.Center + Vector3.new(0, 3, 0), zone.Radius + 3, zone.EndsAt - now)
	elseif mode == "Singularity" then
		return -- dano so na implosao
	else
		for _, target in hostilesIn(zone) do
			if mode == "Rain" then
				-- Encharcado: prepara Conducao (eletricidade x1,5) e Vaporizar (fogo).
				StatusService.apply(target, States.Wet, 4, { Source = ctx.Caster })
			end
			local multiplier = 1
			if mode == "Static" then
				-- Plasma Field: o pulso fere mais na borda.
				local distance = ((Targeting.position(target) - zone.Center) * FLAT).Magnitude
				multiplier = SpellMath.staticFieldMultiplier(distance, zone.Radius)
			elseif mode == "Rain" then
				multiplier = zone.Tick
			end
			Context.damage(ctx, target, row.Damage * multiplier)
			Context.tryProc(ctx, target)
		end
		if mode == "Static" then
			vfx:FireAllClients("StaticPulse", { Caster = ctx.Caster, Radius = zone.Radius, School = row.School })
		end
		if mode == "Rain" and row.EffectValue > 0 then
			-- Cura aliados na chuva (inclusive o conjurador e servos).
			for model, stats in StatsService.all() do
				if
					stats.Humanoid.Health > 0
					and not Targeting.isHostile(ctx.Caster, model)
					and ((Targeting.position(model) - zone.Center) * FLAT).Magnitude <= zone.Radius
				then
					DamageService.heal(model, row.EffectValue * zone.Tick)
				end
			end
		end
	end
end

local function finish(zone: Zone)
	local ctx = zone.Ctx
	if zone.Barrier then
		zone.Barrier:Destroy()
	end
	if zone.Mode == "Singularity" and ctx.Caster.Parent then
		for _, target in hostilesIn(zone) do
			Context.damage(ctx, target, ctx.Spell.Row.Damage)
			Context.tryProc(ctx, target)
			local away = (Targeting.position(target) - zone.Center) * FLAT
			Area.push(target, (if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis) * 30 + Vector3.new(0, 18, 0))
		end
	end
	vfx:FireAllClients("ZoneEnd", { Id = zone.Id, Mode = zone.Mode, Position = zone.Center, Radius = zone.Radius })
end

function Zone.start()
	CollisionGroups.ensure()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for i = #zones, 1, -1 do
			local zone = zones[i]
			local alive = StatsService.isAlive(zone.Ctx.Caster)
			if now >= zone.EndsAt or (zone.Mode == "Static" and not alive) then
				table.remove(zones, i)
				finish(zone)
				continue
			end
			if zone.Mode == "Static" then
				zone.Center = Area.groundBelow(Targeting.position(zone.Ctx.Caster), zone.Ctx.Caster)
			end
			if (zone.Mode == "Vortex" or zone.Mode == "Singularity") and now >= zone.NextPull then
				zone.NextPull = now + PULL_INTERVAL
				pull(zone, Units.meters(zone.Ctx.Spell.Row.EffectValue))
			end
			if now >= zone.NextTick then
				zone.NextTick += zone.Tick
				tick(zone, now)
			end
		end
	end)
end

return Zone
