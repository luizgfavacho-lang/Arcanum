--!strict
-- Projeteis simulados no SERVIDOR sem Parts (spherecast por passo no Heartbeat). Os clientes
-- recebem ProjectileSpawn/ProjectileEnd e desenham o visual, simulando o mesmo trajeto.
-- Numeros do CSV: Damage, SpeedMetersPerSecond, RangeMeters, Count (+ExtraCount),
-- MaxTargets (perfuracao), RadiusMeters (explosao no fim), ProcChance/ProcDuration/ProcDPS.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)
local Units = require(Shared.Units)
local Targeting = require(script.Parent.Parent.Combat.Targeting)
local Context = require(script.Parent.Context)

local vfx = Net.get("Vfx")

local COLLISION_RADIUS = 0.8
local MAGNET_DISTANCE = Units.meters(0.6) -- "ima" dos teleguiados
local HOMING_TURN_RATE = 7 -- quanto maior, mais fechada a curva
local HOMING_SEARCH_METERS = 15

type Projectile = {
	Id: string,
	Ctx: Context.Context,
	Position: Vector3,
	Velocity: Vector3,
	Speed: number,
	Travelled: number,
	Range: number,
	MaxHits: number,
	Hits: { [Model]: boolean },
	Homing: Model?,
	Params: RaycastParams,
}

local Projectile = {}

-- (conjurador, posicao, velocidade) de cada projetil criado: a IA usa para tentar desviar.
Projectile.Launched = Signal.new() :: Signal.Signal<Model, Vector3, Vector3>

local active: { [string]: Projectile } = {}

local function finish(p: Projectile, position: Vector3)
	active[p.Id] = nil
	local row = p.Ctx.Spell.Row
	local radius = Units.meters(row.RadiusMeters)
	if radius > 0 then
		for _, target in Targeting.hostilesInRadius(p.Ctx.Caster, position, radius) do
			if not p.Hits[target] then
				Context.damage(p.Ctx, target, row.Damage)
				Context.tryProc(p.Ctx, target)
			end
		end
	end
	vfx:FireAllClients("ProjectileEnd", { Id = p.Id, Position = position, School = row.School, Radius = radius })
end

local function hit(p: Projectile, target: Model, position: Vector3)
	if p.Hits[target] then
		return
	end
	p.Hits[target] = true
	Context.damage(p.Ctx, target, p.Ctx.Spell.Row.Damage)
	Context.tryProc(p.Ctx, target)

	-- Perfuracao: o alvo atingido sai do filtro de colisao.
	local filter = p.Params.FilterDescendantsInstances
	table.insert(filter, target)
	p.Params.FilterDescendantsInstances = filter

	local count = 0
	for _ in p.Hits do
		count += 1
	end
	if count >= p.MaxHits then
		finish(p, position)
	end
end

local function step(p: Projectile, dt: number)
	local homing = p.Homing
	if homing and Targeting.isHostile(p.Ctx.Caster, homing) then
		local targetPos = Targeting.position(homing)
		if (targetPos - p.Position).Magnitude <= MAGNET_DISTANCE + 2 then
			hit(p, homing, targetPos)
			if not active[p.Id] then
				return
			end
			p.Homing = nil
		else
			local desired = (targetPos - p.Position).Unit * p.Speed
			p.Velocity = p.Velocity:Lerp(desired, math.clamp(dt * HOMING_TURN_RATE, 0, 1))
		end
	end

	local delta = p.Velocity * dt
	local result = Workspace:Spherecast(p.Position, COLLISION_RADIUS, delta, p.Params)
	if result then
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model and Targeting.isHostile(p.Ctx.Caster, model) then
			hit(p, model, result.Position)
			if not active[p.Id] then
				return
			end
		elseif not (model and model:FindFirstChildOfClass("Humanoid")) then
			-- Geometria do mundo (aliados sao atravessados).
			finish(p, result.Position)
			return
		end
	end

	p.Position += delta
	p.Travelled += delta.Magnitude
	if p.Travelled >= p.Range then
		finish(p, p.Position)
	end
end

function Projectile.cast(ctx: Context.Context)
	local row = ctx.Spell.Row
	local def = ctx.Spell.Def
	local count = math.max(row.Count + ctx.Mods.ExtraCount, 1)
	local speed = Units.meters(row.SpeedMetersPerSecond)
	local range = Units.meters(row.RangeMeters)

	-- O projetil sai do cajado mas converge para onde a camera aponta.
	local aimTarget, aimPoint = Targeting.aimTrace(ctx.Caster, ctx.Origin, Context.direction(ctx), range, 1.2)
	local muzzle = Targeting.muzzle(ctx.Caster)
	local baseDirection = (aimPoint - muzzle).Unit

	local homingTargets: { Model } = {}
	if def.Homing then
		local used: { [Model]: boolean } = {}
		if aimTarget then
			table.insert(homingTargets, aimTarget)
			used[aimTarget] = true
		end
		while #homingTargets < count do
			local extra = Targeting.nearestHostile(ctx.Caster, aimPoint, Units.meters(HOMING_SEARCH_METERS), used)
			if not extra then
				break
			end
			used[extra] = true
			table.insert(homingTargets, extra)
		end
	end

	local spread = def.SpreadDegrees or 0
	for index = 1, count do
		-- Leque: espalha na horizontal e alterna para cima/baixo (orbes em arco, nao em fila).
		local alpha = if count > 1 then (index - 1) / (count - 1) - 0.5 else 0
		local lift = if count > 1 then (if index % 2 == 0 then 1 else -0.5) * spread * 0.35 else 0
		local right = baseDirection:Cross(Vector3.yAxis)
		right = if right.Magnitude > 1e-3 then right.Unit else Vector3.xAxis
		local flat = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(alpha * spread)):VectorToWorldSpace(baseDirection)
		local direction = CFrame.fromAxisAngle(right, math.rad(lift)):VectorToWorldSpace(flat)

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { ctx.Caster }

		local homing = if #homingTargets > 0 then homingTargets[(index - 1) % #homingTargets + 1] else nil
		local p: Projectile = {
			Id = HttpService:GenerateGUID(false),
			Ctx = ctx,
			Position = muzzle,
			Velocity = direction * speed,
			Speed = speed,
			Travelled = 0,
			Range = range,
			MaxHits = math.max(row.MaxTargets, 1),
			Hits = {},
			Homing = homing,
			Params = params,
		}
		active[p.Id] = p
		vfx:FireAllClients("ProjectileSpawn", {
			Id = p.Id,
			SpellId = ctx.Spell.Id,
			Position = p.Position,
			Velocity = p.Velocity,
			Speed = speed,
			Homing = homing,
			School = row.School,
			Caster = ctx.Caster,
		})
		Projectile.Launched:Fire(ctx.Caster, p.Position, p.Velocity)
	end
end

function Projectile.start()
	RunService.Heartbeat:Connect(function(dt)
		for _, p in active do
			step(p, dt)
		end
	end)
end

return Projectile
