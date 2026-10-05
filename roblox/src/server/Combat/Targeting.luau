--!strict
-- Consultas de alvo do servidor: hostilidade, mira, vizinho mais proximo e cadeia.

local Workspace = game:GetService("Workspace")

local StatsService = require(script.Parent.Parent.Services.StatsService)

local Targeting = {}

function Targeting.position(model: Model): Vector3
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else model:GetPivot().Position
end

-- Ponto de saida das magias: mao direita (cajado) ou na frente da cabeca.
function Targeting.muzzle(model: Model): Vector3
	local hand = model:FindFirstChild("RightHand") :: BasePart?
	if hand then
		return hand.Position
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		return head.Position + head.CFrame.LookVector * 2
	end
	return Targeting.position(model)
end

function Targeting.isHostile(source: Model?, target: Model?): boolean
	if not source or not target or source == target then
		return false
	end
	local sourceStats = StatsService.get(source)
	local targetStats = StatsService.get(target)
	return sourceStats ~= nil
		and targetStats ~= nil
		and targetStats.Humanoid.Health > 0
		and sourceStats.Team ~= targetStats.Team
end

local function combatantFromPart(part: Instance): Model?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if StatsService.get(model) then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- Spherecast pela mira. Retorna (alvo hostil ou nil, ponto de impacto).
function Targeting.aimTrace(
	caster: Model,
	origin: Vector3,
	direction: Vector3,
	range: number,
	radius: number
): (Model?, Vector3)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { caster }

	local dir = direction.Unit * range
	local result = Workspace:Spherecast(origin, radius, dir, params)
	if not result then
		return nil, origin + dir
	end
	local model = combatantFromPart(result.Instance)
	if model and Targeting.isHostile(caster, model) then
		return model, result.Position
	end
	return nil, result.Position
end

function Targeting.nearestHostile(
	caster: Model,
	position: Vector3,
	radius: number,
	exclude: { [Model]: boolean }?
): Model?
	local best: Model? = nil
	local bestDist = radius
	for model in StatsService.all() do
		if not (exclude and exclude[model]) and Targeting.isHostile(caster, model) then
			local dist = (Targeting.position(model) - position).Magnitude
			if dist <= bestDist then
				best, bestDist = model, dist
			end
		end
	end
	return best
end

function Targeting.hostilesInRadius(caster: Model, position: Vector3, radius: number): { Model }
	local result = {}
	for model in StatsService.all() do
		if Targeting.isHostile(caster, model) and (Targeting.position(model) - position).Magnitude <= radius then
			table.insert(result, model)
		end
	end
	return result
end

-- Cadeia: cada salto vai ao hostil mais proximo do anterior, sem repetir.
function Targeting.chain(caster: Model, first: Model, maxTargets: number, jumpRadius: number): { Model }
	local targets = { first }
	local used = { [first] = true }
	while #targets < maxTargets do
		local nextTarget = Targeting.nearestHostile(caster, Targeting.position(targets[#targets]), jumpRadius, used)
		if not nextTarget then
			break
		end
		used[nextTarget] = true
		table.insert(targets, nextTarget)
	end
	return targets
end

return Targeting
