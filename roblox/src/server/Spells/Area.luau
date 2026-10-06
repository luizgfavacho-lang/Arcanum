--!strict
-- Magias de area (Circulo II do Grimorio):
--   Strike  Raio Invocado: raio do ceu no ponto mirado (RangeMeters), fere no RadiusMeters.
--   Nova    Nova Flamejante / Pulso Arcano: explosao em volta do conjurador (RadiusMeters) que
--           empurra (EffectValue m/s); o Pulso tambem apaga projeteis hostis (DestroysProjectiles).
--   Line    Espinhos Carmesins: fileira a partir dos pes na direcao da mira (RangeMeters de
--           comprimento, RadiusMeters de meia-largura) que arremessa para cima (EffectValue m/s).
-- Empurrao so em criaturas (fisica no servidor); o personagem do jogador e do cliente.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Units = require(Shared.Units)
local Targeting = require(script.Parent.Parent.Combat.Targeting)
local Context = require(script.Parent.Context)
local Projectile = require(script.Parent.Projectile)

local vfx = Net.get("Vfx")

local Area = {}

local FLAT = Vector3.new(1, 0, 1)
local BODY_HEIGHT = 2.5 -- do chao ao centro do corpo (raiz do R15)

local function push(target: Model, velocity: Vector3)
	if Players:GetPlayerFromCharacter(target) then
		return
	end
	local root = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "SpellPush"
	attachment.Parent = root
	local force = Instance.new("LinearVelocity")
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	force.VectorVelocity = velocity
	force.MaxForce = math.huge
	force.Parent = root
	Debris:AddItem(force, 0.18)
	Debris:AddItem(attachment, 0.2)
end

local function groundBelow(position: Vector3, ignore: Instance): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore }
	local hit = Workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position else position
end

local function flatDirection(ctx: Context.Context): Vector3
	local dir = Context.direction(ctx) * FLAT
	if dir.Magnitude < 1e-3 then
		local root = ctx.Caster:FindFirstChild("HumanoidRootPart") :: BasePart?
		dir = if root then root.CFrame.LookVector * FLAT else Vector3.zAxis
	end
	return dir.Unit
end

function Area.strike(ctx: Context.Context)
	local row = ctx.Spell.Row
	local range = Units.meters(row.RangeMeters)
	local radius = Units.meters(row.RadiusMeters)
	local _, point = Targeting.aimTrace(ctx.Caster, ctx.Origin, Context.direction(ctx), range, 0.5)
	local center = groundBelow(point, ctx.Caster)
	-- Aviso curto (nuvem e circulo no chao) antes do raio cair; dano no instante do raio.
	vfx:FireAllClients("StrikeWarn", { Position = center, Radius = radius, Duration = 0.35, School = row.School })
	task.delay(0.35, function()
		vfx:FireAllClients("Strike", { Position = center, Radius = radius, School = row.School, Caster = ctx.Caster })
		for _, target in Targeting.hostilesInRadius(ctx.Caster, center + Vector3.new(0, BODY_HEIGHT, 0), radius + 1.5) do
			Context.damage(ctx, target, row.Damage)
			Context.tryProc(ctx, target)
		end
	end)
end

function Area.nova(ctx: Context.Context)
	local row = ctx.Spell.Row
	local radius = Units.meters(row.RadiusMeters)
	local center = Targeting.position(ctx.Caster)
	local popped = if ctx.Spell.Def.DestroysProjectiles
		then Projectile.destroyHostileNear(ctx.Caster, center, radius)
		else {}
	vfx:FireAllClients(
		"Nova",
		{ Position = center, Radius = radius, School = row.School, Caster = ctx.Caster, Popped = popped }
	)
	local speed = Units.meters(row.EffectValue)
	for _, target in Targeting.hostilesInRadius(ctx.Caster, center, radius) do
		Context.damage(ctx, target, row.Damage)
		Context.tryProc(ctx, target)
		if speed > 0 then
			local away = (Targeting.position(target) - center) * FLAT
			away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
			push(target, away * speed + Vector3.new(0, speed * 0.35, 0))
		end
	end
end

function Area.line(ctx: Context.Context)
	local row = ctx.Spell.Row
	local direction = flatDirection(ctx)
	local length = Units.meters(row.RangeMeters)
	local width = Units.meters(row.RadiusMeters) * 2
	local from = groundBelow(Targeting.position(ctx.Caster), ctx.Caster) + direction * 1.5
	local to = from + direction * length
	vfx:FireAllClients("SpellLine", { From = from, To = to, Width = width, School = row.School, Caster = ctx.Caster })
	local lift = Units.meters(row.EffectValue)
	task.delay(0.1, function()
		local mid = (from + to) / 2
		for _, target in Targeting.hostilesInRadius(ctx.Caster, mid, length / 2 + width + BODY_HEIGHT) do
			if Targeting.distanceToSegment(Targeting.position(target), from, to) <= width / 2 + 1.5 then
				Context.damage(ctx, target, row.Damage)
				Context.tryProc(ctx, target)
				if lift > 0 then
					push(target, Vector3.new(0, lift, 0) + direction * lift * 0.3)
				end
			end
		end
	end)
end

return Area
