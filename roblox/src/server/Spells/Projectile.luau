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
local Hazard = require(script.Parent.Hazard)

local vfx = Net.get("Vfx")
local vfxFast = Net.get("VfxFast")

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
	FrozenUntil: number, -- Ampulheta Partida: parado no ar ate este instante
	NextShock: number, -- Bola de Relampago: proximo choque em volta
}

local Projectile = {}

-- (conjurador, posicao, velocidade) de cada projetil criado: a IA usa para tentar desviar.
Projectile.Launched = Signal.new() :: Signal.Signal<Model, Vector3, Vector3>

local active: { [string]: Projectile } = {}

local function finish(p: Projectile, position: Vector3)
	active[p.Id] = nil
	if p.Ctx.Spell.Def.LavaPool then
		Hazard.lavaPool(p.Ctx, position) -- Lanca de Magma: poca onde a lanca termina
	end
	local row = p.Ctx.Spell.Row
	local radius = Units.meters(row.RadiusMeters)
	-- Bola de Relampago: a explosao final usa SecondaryDamage (o Damage e o choque por tick).
	-- Outros (Bola de Fogo): SecondaryDamage > 0 = dano da explosao em volta (o golpe direto usa Damage).
	local finalDamage = if p.Ctx.Spell.Def.ShockOrb or row.SecondaryDamage > 0 then row.SecondaryDamage else row.Damage
	if radius > 0 then
		for _, target in Targeting.hostilesInRadius(p.Ctx.Caster, position, radius) do
			if not p.Hits[target] or p.Ctx.Spell.Def.ShockOrb then
				Context.damage(p.Ctx, target, finalDamage)
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
	local dealt = Context.damage(p.Ctx, target, p.Ctx.Spell.Row.Damage)
	Context.tryProc(p.Ctx, target)
	-- Almas Errantes: a alma volta ao conjurador trazendo a cura.
	if dealt > 0 and p.Ctx.Spell.Row.HealFraction > 0 then
		vfx:FireAllClients("SoulReturn", { From = position, Caster = p.Ctx.Caster, School = p.Ctx.Spell.Row.School })
	end

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

-- Bola de Relampago: choque em ate MaxTargets inimigos a SecondaryRadius, a cada Tick.
local function shock(p: Projectile)
	local ctx = p.Ctx
	local row = ctx.Spell.Row
	local reach = Units.meters(row.SecondaryRadiusMeters)
	local victims = Targeting.hostilesInRadius(ctx.Caster, p.Position, reach)
	table.sort(victims, function(a, b)
		return (Targeting.position(a) - p.Position).Magnitude < (Targeting.position(b) - p.Position).Magnitude
	end)
	local points = {}
	for i = 1, math.min(#victims, math.max(row.MaxTargets, 1)) do
		Context.damage(ctx, victims[i], row.Damage)
		Context.tryProc(ctx, victims[i])
		table.insert(points, Targeting.position(victims[i]))
	end
	if #points > 0 then
		vfxFast:FireAllClients("OrbShock", { From = p.Position, Points = points, School = row.School })
	end
end

local function step(p: Projectile, dt: number)
	local now = os.clock()
	if now < p.FrozenUntil then
		return -- tempo parado
	end
	local def = p.Ctx.Spell.Def
	if def.ShockOrb and now >= p.NextShock then
		p.NextShock = now + math.max(p.Ctx.Spell.Row.TickIntervalSeconds, 0.1)
		shock(p)
	end
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
		if model and def.ShockOrb and model:FindFirstChildOfClass("Humanoid") then
			-- O orbe atravessa criaturas (fere so pelos choques).
			local filter = p.Params.FilterDescendantsInstances
			table.insert(filter, model)
			p.Params.FilterDescendantsInstances = filter
		elseif model and Targeting.isHostile(p.Ctx.Caster, model) then
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

	-- Rosa dos Lamentos: nasce na rosa (aos pes) e sai em todas as direcoes, na horizontal.
	local start = muzzle
	if def.Radial then
		start = Targeting.position(ctx.Caster) - Vector3.new(0, 1, 0)
		local look = Context.direction(ctx) * Vector3.new(1, 0, 1)
		baseDirection = if look.Magnitude > 1e-3 then look.Unit else Vector3.zAxis
		vfx:FireAllClients("Rose", { Caster = ctx.Caster, Position = start, School = row.School })
	end

	local spread = def.SpreadDegrees or 0
	for index = 1, count do
		local direction: Vector3
		if def.Radial then
			direction = CFrame.fromAxisAngle(Vector3.yAxis, (index - 1) / count * math.pi * 2)
				:VectorToWorldSpace(baseDirection)
		else
			-- Leque: espalha na horizontal e alterna para cima/baixo (orbes em arco, nao em fila).
			local alpha = if count > 1 then (index - 1) / (count - 1) - 0.5 else 0
			local lift = if count > 1 then (if index % 2 == 0 then 1 else -0.5) * spread * 0.35 else 0
			local right = baseDirection:Cross(Vector3.yAxis)
			right = if right.Magnitude > 1e-3 then right.Unit else Vector3.xAxis
			local flat = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(alpha * spread)):VectorToWorldSpace(baseDirection)
			direction = CFrame.fromAxisAngle(right, math.rad(lift)):VectorToWorldSpace(flat)
		end

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { ctx.Caster }

		local homing = if #homingTargets > 0 then homingTargets[(index - 1) % #homingTargets + 1] else nil
		local p: Projectile = {
			Id = HttpService:GenerateGUID(false),
			Ctx = ctx,
			Position = start,
			Velocity = direction * speed,
			Speed = speed,
			Travelled = 0,
			Range = range,
			MaxHits = if def.ShockOrb then math.huge else math.max(row.MaxTargets, 1),
			Hits = {},
			Homing = homing,
			Params = params,
			FrozenUntil = 0,
			NextShock = os.clock() + 0.2,
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

-- Pulso Arcano: apaga projeteis de inimigos do conjurador dentro do raio. Retorna onde estavam.
function Projectile.destroyHostileNear(caster: Model, center: Vector3, radius: number): { Vector3 }
	local positions = {}
	for _, p in active do
		if Targeting.isHostile(caster, p.Ctx.Caster) and (p.Position - center).Magnitude <= radius then
			table.insert(positions, p.Position)
			finish(p, p.Position)
		end
	end
	return positions
end

-- Ampulheta Partida: projeteis hostis ao conjurador dentro da esfera param no ar.
function Projectile.freezeHostile(caster: Model, center: Vector3, radius: number, duration: number)
	local now = os.clock()
	for _, p in active do
		if
			(p.Position - center).Magnitude <= radius
			and p.Ctx.Caster ~= caster
			and Targeting.isHostile(caster, p.Ctx.Caster)
		then
			if p.FrozenUntil < now then
				vfxFast:FireAllClients("ProjectileFreeze", { Id = p.Id, Duration = duration })
			end
			p.FrozenUntil = now + duration
		end
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
