--!strict
-- Lamina de Sangue (Kind "Slash"): golpe em arco a frente (mira) com uma lamina de sangue
-- solidificado. Alcance RadiusMeters, abertura de 140 graus; Damage em cada inimigo do arco e
-- sangramento (Proc). O custo em vida (HealthCostPct) e cobrado pelo SpellService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Units = require(Shared.Units)
local Targeting = require(script.Parent.Parent.Combat.Targeting)
local Context = require(script.Parent.Context)

local vfx = Net.get("Vfx")

local FLAT = Vector3.new(1, 0, 1)
local HALF_ARC = math.cos(math.rad(70))

local Melee = {}

function Melee.slash(ctx: Context.Context)
	local row = ctx.Spell.Row
	local origin = Targeting.position(ctx.Caster)
	local direction = Context.direction(ctx) * FLAT
	if direction.Magnitude < 1e-3 then
		local root = ctx.Caster:FindFirstChild("HumanoidRootPart") :: BasePart?
		direction = if root then root.CFrame.LookVector * FLAT else Vector3.zAxis
	end
	direction = direction.Unit
	local reach = Units.meters(row.RadiusMeters) + 2.5
	vfx:FireAllClients("BloodSlash", { Caster = ctx.Caster, Direction = direction, Reach = reach, School = row.School })
	task.delay(0.08, function()
		for _, target in Targeting.hostilesInRadius(ctx.Caster, origin, reach + 2) do
			local offset = (Targeting.position(target) - origin) * FLAT
			if offset.Magnitude < 2 or offset.Unit:Dot(direction) >= HALF_ARC then
				Context.damage(ctx, target, row.Damage)
				Context.tryProc(ctx, target)
			end
		end
	end)
end

return Melee
