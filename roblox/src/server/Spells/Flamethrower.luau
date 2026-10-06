--!strict
-- Piromania (canalizada): lanca-chamas. Enquanto o botao estiver segurado, a cada TickIntervalSeconds
-- drena ManaPerSecond, e todos os inimigos no cone a frente da gema (ate RangeMeters, abrindo ate
-- RadiusMeters de raio na ponta) levam Damage por segundo e pegam fogo (ProcChance por segundo).
-- Paredes e terreno bloqueiam o fogo; criaturas nao (o fogo envolve o grupo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local States = require(Shared.States)
local Units = require(Shared.Units)
local Services = script.Parent.Parent.Services
local StatsService = require(Services.StatsService)
local StatusService = require(Services.StatusService)
local Targeting = require(script.Parent.Parent.Combat.Targeting)
local Context = require(script.Parent.Context)

local vfx = Net.get("Vfx")
local vfxFast = Net.get("VfxFast")

local NOZZLE_RADIUS = 1.2 -- studs: largura do cone logo na saida da gema

local Flamethrower = {}

-- O fogo chega ate o ponto? So terreno e cenario bloqueiam (criaturas ficam de fora do raio).
local function reaches(caster: Model, from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { caster }
	for model in StatsService.all() do
		table.insert(ignore, model)
	end
	params.FilterDescendantsInstances = ignore
	return Workspace:Raycast(from, to - from, params) == nil
end

-- Alvos no cone (posicao, eixo unitario, alcance e raio final em studs).
function Flamethrower.coneTargets(
	caster: Model,
	from: Vector3,
	axis: Vector3,
	range: number,
	endRadius: number
): { Model }
	local hits = {}
	for _, target in Targeting.hostilesInRadius(caster, from, range + 2) do
		local offset = Targeting.position(target) - from
		local along = offset:Dot(axis)
		if along > -1 and along <= range then
			local lateral = (offset - axis * along).Magnitude
			local allowed = NOZZLE_RADIUS + (endRadius - NOZZLE_RADIUS) * math.clamp(along / range, 0, 1) + 1.5
			if lateral <= allowed and reaches(caster, from, from + axis * math.max(along, 0)) then
				table.insert(hits, target)
			end
		end
	end
	return hits
end

function Flamethrower.start(ctx: Context.Context)
	local row = ctx.Spell.Row
	local interval = if row.TickIntervalSeconds > 0 then row.TickIntervalSeconds else 0.15
	local range = Units.meters(row.RangeMeters)
	local endRadius = Units.meters(row.RadiusMeters)
	ctx.Caster:SetAttribute("Channeling", ctx.Spell.Id)
	task.spawn(function()
		while not ctx.Stopped do
			local stats = StatsService.get(ctx.Caster)
			if not stats or stats.Humanoid.Health <= 0 or StatusService.has(ctx.Caster, States.Paralyzed) then
				break
			end
			if not StatsService.drainMana(stats, row.ManaPerSecond * interval * ctx.Mods.CostMultiplier) then
				break
			end
			local from = Targeting.muzzle(ctx.Caster)
			local aim = ctx.AimPoint - from
			local axis = if aim.Magnitude > 1e-3 then aim.Unit else Context.direction(ctx)
			local hitPositions = {}
			for _, target in Flamethrower.coneTargets(ctx.Caster, from, axis, range, endRadius) do
				Context.damage(ctx, target, row.Damage * interval)
				Context.tryProc(ctx, target, interval)
				table.insert(hitPositions, Targeting.position(target))
			end
			vfxFast:FireAllClients("Flamethrower", {
				Caster = ctx.Caster,
				Direction = axis,
				Range = range,
				Radius = endRadius,
				Hits = hitPositions,
				School = row.School,
			})
			task.wait(interval)
		end
		ctx.Stopped = true
		if ctx.Caster.Parent then
			ctx.Caster:SetAttribute("Channeling", nil)
		end
		vfx:FireAllClients("ChannelEnd", { Caster = ctx.Caster })
		if ctx.OnEnded then
			ctx.OnEnded()
		end
	end)
end

return Flamethrower
