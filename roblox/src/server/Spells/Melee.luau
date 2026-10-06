--!strict
-- Lamina de Sangue (Kind "Slash"): golpe em arco a frente (mira) com uma lamina de sangue
-- solidificado. Alcance RadiusMeters, abertura de 140 graus; Damage em cada inimigo do arco e
-- sangramento (Proc). Ponta da lamina (Darkin Blade, Aatrox): quem esta na ponta leva +50% e e
-- jogado para tras. O custo em vida (HealthCostPct) e cobrado pelo SpellService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local SpellMath = require(Shared.Math.SpellMath)
local Units = require(Shared.Units)
local Targeting = require(script.Parent.Parent.Combat.Targeting)
local Context = require(script.Parent.Context)
local Area = require(script.Parent.Area)

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
		local sweetSpots: { Vector3 } = {}
		for _, target in Targeting.hostilesInRadius(ctx.Caster, origin, reach + 2) do
			local offset = (Targeting.position(target) - origin) * FLAT
			if offset.Magnitude < 2 or offset.Unit:Dot(direction) >= HALF_ARC then
				local multiplier, sweet = SpellMath.bladeMultiplier(offset.Magnitude, reach)
				Context.damage(ctx, target, row.Damage * multiplier)
				Context.tryProc(ctx, target)
				if sweet then
					table.insert(sweetSpots, Targeting.position(target))
					Area.push(target, offset.Unit * 28 + Vector3.new(0, 10, 0))
				end
			end
		end
		if #sweetSpots > 0 then
			vfx:FireAllClients("SweetSpot", { Positions = sweetSpots, School = row.School })
		end
	end)
end

return Melee
