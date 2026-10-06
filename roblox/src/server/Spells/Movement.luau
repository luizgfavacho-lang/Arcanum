--!strict
-- Deslocamento:
--   Blink   Passo Relampago: teleporte de RangeMeters na direcao da mira (para antes de paredes);
--           eletrocuta (Damage) quem estiver no caminho, a RadiusMeters da linha, e deixa no ponto de
--           partida um resquicio que explode depois de EffectValue s (SecondaryDamage em
--           SecondaryRadiusMeters; Static Remnant, Storm Spirit/DotA).
--   Portal  Portal Arcano: par de portais (a frente do mago e no ponto mirado, ate RangeMeters) por
--           DurationSeconds; quem entra num sai no outro. Ate Count pares por mago (o mais velho fecha).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Units = require(Shared.Units)
local StatsService = require(script.Parent.Parent.Services.StatsService)
local Targeting = require(script.Parent.Parent.Combat.Targeting)
local Context = require(script.Parent.Context)
local Area = require(script.Parent.Area)

local vfx = Net.get("Vfx")

local FLAT = Vector3.new(1, 0, 1)
local PORTAL_REACH = 3.5 -- studs do centro do portal para entrar
local PORTAL_COOLDOWN = 1.2 -- nao volta pelo outro portal logo em seguida
local ROOT_HEIGHT = 3

type Portal = {
	Id: string,
	Owner: Model,
	A: Vector3,
	B: Vector3,
	FacingA: Vector3,
	FacingB: Vector3,
	EndsAt: number,
}

local Movement = {}

local portals: { Portal } = {}
local lastTeleport: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function obstacles(caster: Model): RaycastParams
	local ignore: { Instance } = { caster }
	for model in StatsService.all() do
		table.insert(ignore, model)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

local function flatAim(ctx: Context.Context): Vector3
	local dir = Context.direction(ctx) * FLAT
	if dir.Magnitude < 1e-3 then
		local root = ctx.Caster:FindFirstChild("HumanoidRootPart") :: BasePart?
		dir = if root then root.CFrame.LookVector * FLAT else Vector3.zAxis
	end
	return dir.Unit
end

function Movement.blink(ctx: Context.Context)
	local row = ctx.Spell.Row
	local root = ctx.Caster:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local direction = flatAim(ctx)
	local from = root.Position
	local distance = Units.meters(row.RangeMeters)
	local wall = Workspace:Raycast(from, direction * distance, obstacles(ctx.Caster))
	if wall then
		distance = math.max((wall.Position - from).Magnitude - 2.5, 0)
	end
	local to = Area.groundBelow(from + direction * distance + Vector3.new(0, 3, 0), ctx.Caster)
		+ Vector3.new(0, ROOT_HEIGHT, 0)
	ctx.Caster:PivotTo(CFrame.lookAt(to, to + direction))
	vfx:FireAllClients("LightningStep", { Caster = ctx.Caster, From = from, To = to, School = row.School })
	local width = Units.meters(row.RadiusMeters) + 2
	for _, target in Targeting.hostilesInRadius(ctx.Caster, (from + to) / 2, distance / 2 + width + 2) do
		if Targeting.distanceToSegment(Targeting.position(target), from, to) <= width then
			Context.damage(ctx, target, row.Damage)
			Context.tryProc(ctx, target)
		end
	end
	local remnantRadius = Units.meters(row.SecondaryRadiusMeters)
	if row.SecondaryDamage > 0 and remnantRadius > 0 then
		local delay = if row.EffectValue > 0 then row.EffectValue else 0.6
		vfx:FireAllClients(
			"Remnant",
			{ Position = from, Delay = delay, Radius = remnantRadius, School = row.School, Caster = ctx.Caster }
		)
		task.delay(delay, function()
			vfx:FireAllClients("RemnantBurst", { Position = from, Radius = remnantRadius, School = row.School })
			for _, target in Targeting.hostilesInRadius(ctx.Caster, from, remnantRadius + 1.5) do
				Context.damage(ctx, target, row.SecondaryDamage)
				Context.tryProc(ctx, target)
			end
		end)
	end
end

local function closePortal(portal: Portal)
	vfx:FireAllClients("PortalClose", { Id = portal.Id })
end

function Movement.portal(ctx: Context.Context)
	local row = ctx.Spell.Row
	local caster = ctx.Caster
	local root = caster:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local direction = flatAim(ctx)
	local a = Area.groundBelow(root.Position + direction * 5, caster)
	local _, point = Targeting.aimTrace(caster, ctx.Origin, Context.direction(ctx), Units.meters(row.RangeMeters), 0.5)
	local b = Area.groundBelow(point - direction * 2, caster)
	local mine: { Portal } = {}
	for _, p in portals do
		if p.Owner == caster then
			table.insert(mine, p)
		end
	end
	if #mine >= math.max(row.Count, 1) then
		local oldest = mine[1]
		table.remove(portals, table.find(portals, oldest) :: number)
		closePortal(oldest)
	end
	local portal: Portal = {
		Id = HttpService:GenerateGUID(false),
		Owner = caster,
		A = a,
		B = b,
		FacingA = direction,
		FacingB = direction,
		EndsAt = os.clock() + (if row.DurationSeconds > 0 then row.DurationSeconds else 30),
	}
	table.insert(portals, portal)
	vfx:FireAllClients("Portal", {
		Id = portal.Id,
		A = a,
		B = b,
		Facing = direction,
		Duration = portal.EndsAt - os.clock(),
		School = row.School,
	})
end

local function travel(character: Model, from: Vector3, to: Vector3, facing: Vector3, portalId: string)
	local destination = to + facing * 5.5 + Vector3.new(0, ROOT_HEIGHT, 0)
	character:PivotTo(CFrame.lookAt(destination, destination + facing))
	lastTeleport[character] = os.clock()
	vfx:FireAllClients("PortalUse", { Id = portalId, Model = character, From = from, To = destination })
end

function Movement.start()
	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = os.clock()
			for i = #portals, 1, -1 do
				local portal = portals[i]
				if now > portal.EndsAt or not portal.Owner.Parent then
					table.remove(portals, i)
					closePortal(portal)
					continue
				end
				for _, player in Players:GetPlayers() do
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if character and root and now - (lastTeleport[character] or -math.huge) > PORTAL_COOLDOWN then
						local p = root.Position
						local nearA = ((p - portal.A) * FLAT).Magnitude < PORTAL_REACH
							and math.abs(p.Y - portal.A.Y) < 6
						local nearB = ((p - portal.B) * FLAT).Magnitude < PORTAL_REACH
							and math.abs(p.Y - portal.B.Y) < 6
						if nearA then
							travel(character, portal.A, portal.B, portal.FacingB, portal.Id)
						elseif nearB then
							travel(character, portal.B, portal.A, -portal.FacingA, portal.Id)
						end
					end
				end
			end
		end
	end)
end

return Movement
